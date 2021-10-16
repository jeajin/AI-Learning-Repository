import tensorflow as tf
import numpy as np
import gym
from tensorflow.keras.models import load_model
import tensorflow_probability as tfp
# !/usr/bin/python3 -m pip install --upgrade pip
# !pip3 install box2d-py
from tensorflow.compat.v1 import ConfigProto
from tensorflow.compat.v1 import InteractiveSession
config = ConfigProto()
config.gpu_options.allow_growth = True
session = InteractiveSession(config=config)
from tensorflow.python.client import device_lib
print(device_lib.list_local_devices())

print(tf.config.list_physical_devices('GPU'))

env= gym.make("LunarLanderContinuous-v2")
state_low = env.observation_space.low
state_high = env.observation_space.high
action_low = env.action_space.low
action_high = env.action_space.high
print(state_low)
print(state_high)
print(action_low)
print(action_high)

class RBuffer():
    def __init__(self, maxsize, statedim, naction):
        self.cnt = 0
        self.maxsize = maxsize
        self.state_memory = np.zeros((maxsize, *statedim), dtype=np.float32)
        self.action_memory = np.zeros((maxsize, naction), dtype=np.float32)
        self.reward_memory = np.zeros((maxsize,), dtype=np.float32)
        self.next_state_memory = np.zeros((maxsize, *statedim), dtype=np.float32)
        self.done_memory = np.zeros((maxsize,), dtype= np.bool)

    def storexp(self, state, next_state, action, done, reward):
        index = self.cnt % self.maxsize
        self.state_memory[index] = state
        self.action_memory[index] = action
        self.reward_memory[index] = reward
        self.next_state_memory[index] = next_state
        self.done_memory[index] = 1- int(done)
        self.cnt += 1

    def sample(self, batch_size):
        max_mem = min(self.cnt, self.maxsize)
        batch = np.random.choice(max_mem, batch_size, replace= False)
        states = self.state_memory[batch]
        next_states = self.next_state_memory[batch]
        rewards = self.reward_memory[batch]
        actions = self.action_memory[batch]
        dones = self.done_memory[batch]
        return states, next_states, rewards, actions, dones


class Critic(tf.keras.Model):
    def __init__(self):
        super(Critic, self).__init__()
        self.f1 = tf.keras.layers.Dense(256, activation='relu')
        self.f2 = tf.keras.layers.Dense(256, activation='relu')
        self.q = tf.keras.layers.Dense(1, activation=None)

    def call(self, inputstate, action):
        x = self.f1(tf.concat([inputstate, action], axis=1))
        x = self.f2(x)
        x = self.q(x)
        return x


class value_net(tf.keras.Model):
    def __init__(self):
        super(value_net, self).__init__()
        self.f1 = tf.keras.layers.Dense(256, activation='relu')
        self.f2 = tf.keras.layers.Dense(256, activation='relu')
        self.v = tf.keras.layers.Dense(1, activation=None)

    def call(self, inputstate):
        x = self.f1(inputstate)
        x = self.f2(x)
        x = self.v(x)
        return x


class Actor(tf.keras.Model):
    def __init__(self, no_action):
        super(Actor, self).__init__()
        self.f1 = tf.keras.layers.Dense(256, activation='relu')
        self.f2 = tf.keras.layers.Dense(256, activation='relu')
        self.mu = tf.keras.layers.Dense(no_action, activation=None)
        self.sigma = tf.keras.layers.Dense(no_action, activation=None)
        self.min_action = -1
        self.max_action = 1
        self.repram = 1e-6

    def call(self, state):
        x = self.f1(state)
        x = self.f2(x)
        mu = self.mu(x)
        s = self.sigma(x)
        s = tf.clip_by_value(s, self.repram, 1)
        return mu, s

    def sample_normal(self, state, reparameterize=True):
        mu, sigma = self(state)
        # print(mu)
        # print(sigma)
        # mu = tf.squeeze(mu)
        # sigma =tf.squeeze(sigma)
        # print(mu)
        probabilities = tfp.distributions.Normal(mu, sigma)
        if reparameterize:
            actions = probabilities.sample()
            # actions += tf.random.normal(shape=tf.shape(actions), mean=0.0, stddev=0.1)

        else:
            actions = probabilities.sample()

        action = tf.math.scalar_mul(tf.constant(self.max_action, dtype=tf.float32), tf.math.tanh(actions))
        action = tf.squeeze(action)
        log_prob = probabilities.log_prob(actions)
        log_prob -= tf.math.log(1 - tf.math.pow(action, 2) + self.repram)
        log_prob = tf.reduce_sum(log_prob, axis=1)

        return action, log_prob


class Agent():
    def __init__(self, n_action=len(env.action_space.high)):
        self.actor_main = Actor(n_action)
        self.critic_1 = Critic()
        self.critic_2 = Critic()
        self.value_net = value_net()
        self.target_value_net = value_net()
        self.batch_size = 64
        self.n_actions = len(env.action_space.high)
        self.a_opt = tf.keras.optimizers.Adam(0.001)
        # self.actor_target = tf.keras.optimizers.Adam(.001)
        self.c_opt1 = tf.keras.optimizers.Adam(0.002)
        self.c_opt2 = tf.keras.optimizers.Adam(0.002)
        self.v_opt = tf.keras.optimizers.Adam(0.002)
        # self.critic_target = tf.keras.optimizers.Adam(.002)
        self.memory = RBuffer(1_00_000, env.observation_space.shape, len(env.action_space.high))
        self.trainstep = 0
        # self.replace = 5
        self.gamma = 0.99
        self.min_action = env.action_space.low[0]
        self.max_action = env.action_space.high[0]
        self.scale = 2
        self.tau = 0.005
        self.value_net.compile(optimizer=self.v_opt)

    def act(self, state):
        state = tf.convert_to_tensor([state], dtype=tf.float32)
        action, _ = self.actor_main.sample_normal(state, reparameterize=False)
        # print(action)
        return action

    def savexp(self, state, next_state, action, done, reward):
        self.memory.storexp(state, next_state, action, done, reward)

    def update_target(self, tau=None):
        self.target_value_net.set_weights(self.value_net.get_weights())
        # if tau is None:
        #     tau = self.tau
        #
        # weights1 = []
        # targets1 = self.target_value_net.weights
        # for i, weight in enumerate(self.value_net.weights):
        #     weights1.append(weight * tau + targets1[i] * (1 - tau))
        #     print(weights1[0][0])
        #     self.target_value_net.set_weights(weights1)

    def train(self):
        if self.memory.cnt < self.batch_size:
            return

        states, next_states, rewards, actions, dones = self.memory.sample(self.batch_size)

        states = tf.convert_to_tensor(states, dtype=tf.float32)
        next_states = tf.convert_to_tensor(next_states, dtype=tf.float32)
        rewards = tf.convert_to_tensor(rewards, dtype=tf.float32)
        actions = tf.convert_to_tensor(actions, dtype=tf.float32)
        # dones = tf.convert_to_tensor(dones, dtype= tf.bool)

        with tf.GradientTape() as tape1, tf.GradientTape() as tape2, tf.GradientTape() as tape3, tf.GradientTape() as tape4:
            value = tf.squeeze(self.value_net(states))
            # value = self.value_net(states)
            # value loss
            v_actions, v_log_probs = self.actor_main.sample_normal(states, reparameterize=False)
            # print(v_log_probs)
            # v_log_probs = tf.squeeze(v_log_probs, 1)
            v_q1 = self.critic_1(states, v_actions)
            v_q2 = self.critic_2(states, v_actions)
            v_critic_value = tf.math.minimum(tf.squeeze(v_q1), tf.squeeze(v_q2))
            target_value = v_critic_value - v_log_probs
            # print(target_value)
            value_loss = 0.5 * tf.keras.losses.MSE(target_value, value)

            # actor loss
            a_actions, a_log_probs = self.actor_main.sample_normal(states, reparameterize=True)
            # a_log_probs = tf.squeeze(a_log_probs, 1)
            a_q1 = self.critic_1(states, a_actions)
            a_q2 = self.critic_2(states, a_actions)
            a_critic_value = tf.math.minimum(tf.squeeze(a_q1), tf.squeeze(a_q2))
            actor_loss = a_log_probs - a_critic_value
            actor_loss = tf.reduce_mean(actor_loss)

            next_state_value = tf.squeeze(self.target_value_net(next_states))
            # next_state_value = self.target_value_net(next_states)
            # critic loss
            q_hat = self.scale * rewards + self.gamma * next_state_value * dones
            c_q1 = self.critic_1(states, actions)
            c_q2 = self.critic_2(states, actions)
            critic_loss1 = 0.5 * tf.keras.losses.MSE(q_hat, tf.squeeze(c_q1))
            critic_loss2 = 0.5 * tf.keras.losses.MSE(q_hat, tf.squeeze(c_q2))

        grads1 = tape1.gradient(value_loss, self.value_net.trainable_variables)
        grads2 = tape2.gradient(actor_loss, self.actor_main.trainable_variables)
        grads3 = tape3.gradient(critic_loss1, self.critic_1.trainable_variables)
        grads4 = tape4.gradient(critic_loss2, self.critic_2.trainable_variables)
        self.v_opt.apply_gradients(zip(grads1, self.value_net.trainable_variables))
        self.a_opt.apply_gradients(zip(grads2, self.actor_main.trainable_variables))
        self.c_opt1.apply_gradients(zip(grads3, self.critic_1.trainable_variables))
        self.c_opt2.apply_gradients(zip(grads4, self.critic_2.trainable_variables))

        self.trainstep += 1
        # if self.trainstep % self.replace == 0:
        self.update_target()

    # with tf.device('GPU:0'):


tf.random.set_seed(336699)
agent = Agent(2)
episodes = 20000
ep_reward = []
total_avgr = []
target = False
with tf.device('GPU:0'):
    for s in range(episodes):
        if target == True:
            break
        total_reward = 0
        state = env.reset()
        done = False

        while not done:
            env.render()
            action = agent.act(state)
            # print(action[0])
            next_state, reward, done, _ = env.step(action)
            agent.savexp(state, next_state, action, done, reward)
            agent.train()
            state = next_state
            total_reward += reward
            if done:
                ep_reward.append(total_reward)
                avg_reward = np.mean(ep_reward[-100:])
                total_avgr.append(avg_reward)
                print("total reward after {} steps is {} and avg reward is {}".format(s, total_reward, avg_reward))
                if int(avg_reward) == 200:
                    target = True


env.close()