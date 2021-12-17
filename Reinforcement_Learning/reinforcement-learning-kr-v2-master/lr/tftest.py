import tensorflow as tf
import numpy as np
import tensorflow_probability as tfp
from tensorflow.compat.v1 import ConfigProto
from tensorflow.compat.v1 import InteractiveSession
config = ConfigProto()
config.gpu_options.allow_growth = True
session = InteractiveSession(config=config)
from tensorflow.python.client import device_lib
print(device_lib.list_local_devices())

print(tf.config.list_physical_devices('GPU'))



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


class Actor(tf.keras.Model):
    def __init__(self, no_action):
        super(Actor, self).__init__()
        self.f1 = tf.keras.layers.Dense(256, activation='relu', input_shape=(8, 2,))
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
        # print("mu in Actor", mu)
        # print("sigma in Actor", s)
        return mu, s

    def sample_normal(self, state, reparameterize=True):
        mu, sigma = self(state)
        # print("mu in sample normal", mu)
        # print("sigma in sample normal", sigma)
        # mu = tf.squeeze(mu)
        # sigma =tf.squeeze(sigma)
        # print(mu)
        probabilities = tfp.distributions.Normal(mu, sigma)
        if reparameterize:
            actions = probabilities.sample()
            # actions += tf.random.normal(shape=tf.shape(actions), mean=0.0, stddev=0.01)

        else:
            actions = probabilities.sample()

        action = tf.math.scalar_mul(tf.constant(self.max_action, dtype=tf.float32), tf.math.tanh(actions))
        action = tf.squeeze(action)
        log_prob = probabilities.log_prob(actions)
        log_prob -= tf.math.log(1 - tf.math.pow(action, 2) + self.repram)
        log_prob = tf.reduce_sum(log_prob, axis=1)


        return action, log_prob


a = Actor(1)
data = np.ones([8,2])
print(data)
data = tf.convert_to_tensor([np.reshape(data,-1)], dtype=tf.float32)
print(data)
result, _ = a.sample_normal(state=data)
print(result)