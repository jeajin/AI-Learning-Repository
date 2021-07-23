from .base import Controller
from .base import Action
import numpy as np
import random
from collections import defaultdict
import logging
import pkg_resources
import pandas as pd
from collections import deque
from keras.layers import Dense, GRU, Embedding, Conv1D, MaxPooling1D, Dropout, Flatten
from keras.optimizers import Adam
from keras.models import Sequential


logger = logging.getLogger(__name__)
CONTROL_QUEST = pkg_resources.resource_filename(
    'simglucose', 'params/Quest.csv')
PATIENT_PARA_FILE = pkg_resources.resource_filename(
    'simglucose', 'params/vpatient_params.csv')


class DQLController(Controller):
    def __init__(self, state_size, action_size, episode, previous_time, model):
        self.state_size = state_size
        self.action_size = action_size
        self.episode = episode
        self.quest = pd.read_csv(CONTROL_QUEST)
        self.patient_params = pd.read_csv(PATIENT_PARA_FILE)

        self.actions = 0
        self.learning_rate = 0.001
        self.discount_factor = 0.9
        self.epsilon = 0.3 #1
        self.epsilon_min = 0.01
        self.batch_size = 4
        self.train_start = 10
        self.basal = 0
        self.epsilon_decay = 0.99999
        self.previous_time = previous_time * 12
        # 리플레이 메모리

        self.BGmemory = deque(maxlen=1000)
        self.BGminimemory = deque(maxlen=self.previous_time)

        self.memory = deque(maxlen=1000)
        self.minimemory = deque(maxlen=self.previous_time)

        # 모델과 타깃 모델 생성
        if model == 'g':
            self.model = self.build_gru_model()
            self.target_model = self.build_gru_model()
        elif model == 'c':
            self.model = self.build_cnn_model()
            self.target_model = self.build_cnn_model()
        else:
            self.model = self.build_model()
            self.target_model = self.build_model()

        # 타깃 모델 초기화
        self.update_target_model()

        #환자 정보
        self.quest = pd.read_csv(CONTROL_QUEST)
        self.patient_params = pd.read_csv(PATIENT_PARA_FILE)
        # self.target = target

        self.onetimetest = 1

    def reset(self, obs, reward, done, info):
        name = info.get('patient_name')

        if any(self.quest.Name.str.match(name)):
            params = self.patient_params[self.patient_params.Name.str.match(
                name)]
            u2ss = params.u2ss.values.item()  # unit: pmol/(L*kg)
            BW = params.BW.values.item()      # unit: kg
        else:
            u2ss = 1.43   # unit: pmol/(L*kg)
            BW = 57.0     # unit: kg

        self.basal = u2ss * BW / 6000  # unit: U/min


    def build_model(self):
        model = Sequential()

        model.add(Dense(256, input_shape=(self.previous_time*self.state_size, 1), activation='relu',
                        kernel_initializer='he_uniform'))
        model.add(Dense(256, activation='relu',
                        kernel_initializer='he_uniform'))
        model.add(Flatten())
        model.add(Dense(self.action_size, activation='softmax',
                        kernel_initializer='he_uniform'))
        model.summary()
        model.compile(loss='mse', optimizer=Adam(lr=self.learning_rate))
        return model

    def build_gru_model(self):
        model = Sequential()
        model.add(Dense(128, input_shape=(self.previous_time*self.state_size, 1),
                        activation='relu', kernel_initializer='he_uniform'))
        model.add(GRU(128, return_sequences=True))
        # model.add(GRU(128, return_sequences=True))
        model.add(Flatten())
        model.add(Dense(self.action_size, activation='softmax', kernel_initializer='he_uniform'))
        model.summary()
        model.compile(loss='mse', optimizer=Adam(lr=self.learning_rate))
        return model

    def build_cnn_model(self):
        model = Sequential()

        model.add(Conv1D(32, kernel_size=3, activation='relu',
                         input_shape=(self.previous_time*self.state_size, 1)))
        model.add(MaxPooling1D(pool_size=2))
        model.add(Conv1D(32, kernel_size=3, activation='relu'))
        model.add(MaxPooling1D(pool_size=2))
        model.add(Dense(512, activation='relu',
                        kernel_initializer='he_uniform'))
        model.add(Flatten())
        model.add(Dropout(0.2))
        model.add(Dense(self.action_size, activation='softmax',
                        kernel_initializer='he_uniform'))
        model.summary()
        model.compile(loss='mse', optimizer=Adam(lr=self.learning_rate))
        return model

    def update_target_model(self):
        self.target_model.set_weights(self.model.get_weights())

    def prepolicy(self, state):
        r = random.randrange(self.action_size)
        if r == 0:
            return Action(basal=0, bolus=0)
        elif r == 1:
            return Action(basal=self.basal, bolus=0)
        elif r == 2:
            return Action(basal=self.basal * 5, bolus=0)

    def policy(self, state):
        r = 0
        if np.random.rand() <= self.epsilon:
            r = random.randrange(self.action_size)
        else:
            # q_value = self.model.predict(np.array(list(self.BGminimemory)))
            # print(list(self.BGminimemory))
            q_value = self.model.predict(np.reshape(list(self.BGminimemory), (1, 48, 1)))
            # print("q: ", q_value, "shape", q_value.shape)
            r = np.argmax(q_value[0])
            #print("argmax: ", r, " r: ", q_value[0])
        if r == 0:
            return Action(basal=0, bolus=0)
        elif r == 1:
            return Action(basal=self.basal, bolus=0)
        elif r == 2:
            return Action(basal=self.basal * 5, bolus=0)

    def mini_append_sample(self, state, action, reward, next_state, done):
        self.minimemory.append((state, action, reward, next_state, done))
        self.BGminimemory.append(state)
        # print(random.sample(self.minimemory, 1))

    def append_sample(self, state, action, reward, next_state, done):
        print("state", state)
        self.minimemory.append((state, action, reward, next_state, done))
        self.BGminimemory.append(state)
        self.memory.append(list(self.minimemory))
        self.BGmemory.append(list(self.BGminimemory))

    def train_model(self):
        if self.epsilon > self.epsilon_min:
            self.epsilon *= self.epsilon_decay

        mini_batch = random.sample(self.memory, self.batch_size)

        states = np.zeros((self.batch_size,self.previous_time))
        next_states = np.zeros((self.batch_size, self.previous_time))
        actions, rewards, dones = [], [], []

        # print("test area", mini_batch)
        #
        # print()
        # print(mini_batch[0])
        # print()
        # print("1",mini_batch[0][1])
        # print("2",mini_batch[0][2])
        # print("3",mini_batch[0][3]) #  print("4",mini_batch[0][4])IndexError: list index out of range
        # print()
        # print("6",mini_batch[1][0])
        # print("7",mini_batch[2][0])
        # print("8",mini_batch[3][0]) # print("9",mini_batch[4][0])IndexError: list index out of range
        # print()
        # print("1", mini_batch[0][1][0])
        # print("2", mini_batch[0][1][1])
        # print("3", mini_batch[0][1][2])
        # print("4", mini_batch[0][1][3])
        # print("5", mini_batch[0][1][4])

        for i in range(self.batch_size):
            for j in range(self.previous_time):
                states[i][j] = mini_batch[i][j][0]
                actions.append(mini_batch[i][j][1])
                rewards.append(mini_batch[i][j][2])
                next_states[i][j] = mini_batch[i][j][3]
                dones.append(mini_batch[i][j][4])

        if self.onetimetest == 1:
            self.onetimetest = 0
            # print(states)
            # print(states.shape)

        # 현재 상태에 대한 모델의 큐함수
        print("states", np.reshape(states, (4, 48, 1)).shape)
        target = self.model.predict(np.reshape(states, (4, 48, 1)))
        # 다음 상태에 대한 타깃 모델의 큐함수
        target_val = self.target_model.predict(np.reshape(next_states, (4, 48, 1)))
        # 현재 상태에 대한 모델의 큐함수
        # target = self.model.predict(states)
        # 다음 상태에 대한 타깃 모델의 큐함수
        # target_val = self.target_model.predict(next_states)

        # 벨만 최적 방정식을 이용한 업데이트 타깃
        for i in range(self.batch_size):
            for j in range(self.previous_time):
                if dones[i*self.previous_time+j]:
                    target[i] = rewards[i*self.previous_time+j]
                else:
                    target[i] = rewards[i*self.previous_time+j] + self.discount_factor * (np.amax(target_val[i]))

        # self.model.fit(states, target, batch_size=self.batch_size, epochs=1, verbose=0)
        self.model.fit(np.reshape(states, (4, 48, 1)), target, batch_size=self.batch_size, epochs=1, verbose=0)


