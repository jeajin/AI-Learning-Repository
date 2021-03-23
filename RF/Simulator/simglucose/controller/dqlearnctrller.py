from .base import Controller
from .base import Action
import numpy as np
import random
from collections import defaultdict
import logging
import pkg_resources
import pandas as pd
from collections import deque
from keras.layers import Dense
from keras.optimizers import Adam
from keras.models import Sequential


logger = logging.getLogger(__name__)
CONTROL_QUEST = pkg_resources.resource_filename(
    'simglucose', 'params/Quest.csv')
PATIENT_PARA_FILE = pkg_resources.resource_filename(
    'simglucose', 'params/vpatient_params.csv')


class DQLController(Controller):
    def __init__(self, state_size, action_size):
        self.state_size = state_size
        self.action_size = action_size

        self.quest = pd.read_csv(CONTROL_QUEST)
        self.patient_params = pd.read_csv(PATIENT_PARA_FILE)

        self.actions = 0
        self.learning_rate = 0.001
        self.discount_factor = 0.99
        self.epsilon = 1.
        self.epsilon_min = 0.01
        self.batch_size = 64
        self.train_start = 1000
        self.basal = -1
        self.tempaction = 0

        # 리플레이 메모리, 최대 크기 2000
        self.memory = deque(maxlen=2000)

        # 모델과 타깃 모델 생성
        self.model = self.build_model()
        self.target_model = self.build_model()

        # 타깃 모델 초기화
        self.update_target_model()


    def build_model(self):
        model = Sequential()
        model.add(Dense(24, input_dim=self.state_size, activation='relu',
                        kernel_initializer='he_uniform'))
        model.add(Dense(24, activation='relu',
                        kernel_initializer='he_uniform'))
        model.add(Dense(self.action_size, activation='linear',
                        kernel_initializer='he_uniform'))
        model.summary()
        model.compile(loss='mse', optimizer=Adam(lr=self.learning_rate))
        return model

    def update_target_model(self):
        self.target_model.set_weights(self.model.get_weights())

    def policy(self, observation, reward, done, **kwargs):
        state = observation.CGM
        print(state)
        if np.random.rand() <= self.epsilon:
            # 이곳이 문제다
            print("ran")
            print(random.randrange(self.action_size))
            return Action(basal=random.randrange(self.action_size), bolus=0)
        else:
            q_value = self.model.predict(state)
            np.argmax(q_value[0])
            print("arg")
            print(np.argmax(q_value[0]))
        return Action(basal=np.argmax(q_value[0]), bolus=0)

    def append_sample(self, state, action, reward, next_state, done):
        self.memory.append((state, action, reward, next_state, done))

    def train_model(self):
        if self.epsilon > self.epsilon_min:
            self.epsilon *= self.epsilon_decay

        # 메모리에서 배치 크기만큼 무작위로 샘플 추출
        mini_batch = random.sample(self.memory, self.batch_size)

        states = np.zeros((self.batch_size, self.state_size))
        next_states = np.zeros((self.batch_size, self.state_size))
        actions, rewards, dones = [], [], []

        for i in range(self.batch_size):
            states[i] = mini_batch[i][0]
            actions.append(mini_batch[i][1])
            rewards.append(mini_batch[i][2])
            next_states[i] = mini_batch[i][3]
            dones.append(mini_batch[i][4])

        # 현재 상태에 대한 모델의 큐함수
        # 다음 상태에 대한 타깃 모델의 큐함수
        target = self.model.predict(states)
        target_val = self.target_model.predict(next_states)

        # 벨만 최적 방정식을 이용한 업데이트 타깃
        for i in range(self.batch_size):
            if dones[i]:
                target[i][actions[i]] = rewards[i]
            else:
                target[i][actions[i]] = rewards[i] + self.discount_factor * (
                    np.amax(target_val[i]))

        self.model.fit(states, target, batch_size=self.batch_size,
                       epochs=1, verbose=0)

