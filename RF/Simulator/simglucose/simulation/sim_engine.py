import logging
import time
import os

pathos = True
try:
    from pathos.multiprocessing import ProcessPool as Pool
except ImportError:
    print('You could install pathos to enable parallel simulation.')
    pathos = False

logger = logging.getLogger(__name__)


class SimObj(object):
    def __init__(self,
                 env,
                 controller,
                 sim_time,
                 animate=True,
                 path=None):
        self.env = env
        self.controller = controller
        self.sim_time = sim_time
        self.animate = animate
        self._ctrller_kwargs = None
        self.path = path

    def simulate(self):
        obs, reward, done, info = self.env.reset()
        tic = time.time()
        while self.env.time < self.env.scenario.start_time + self.sim_time:
            if self.animate:
                self.env.render()

            # get_action
            action = self.controller.policy(obs, reward, done, **info)
            print(info.get('patient_state'))
            print(obs.CGM)
            print(action)
            print()
            # step
            obs, reward, done, info = self.env.step(action)
        toc = time.time()
        logger.info('Simulation took {} seconds.'.format(toc - tic))

    def qsimulate(self):
        obs, reward, done, info = self.env.reset()
        tic = time.time()
        while self.env.time < self.env.scenario.start_time + self.sim_time:
            if self.animate:
                self.env.render()
            # get_action
            action = self.controller.policy(obs, reward, done, **info)
            print(action)
            # step
            n_obs, reward, done, info = self.env.step(action)
            # learn
            self.controller.learn(obs.CGM, action, reward, n_obs.CGM)
            obs = n_obs
        toc = time.time()
        logger.info('Simulation took {} seconds.'.format(toc - tic))

    def dqsimulate(self):
        epi = self.controller.episode
        totaltic = time.time()
        for episode in range(epi):
            print('episode {} is start'.format(episode))
            if episode % 1 == 0:
                # self.controller.epsilon -= 0.1
                print(self.controller.epsilon)
                # print("episode is "+str(episode))

            obs, reward, done, info = self.env.reset()
            tic = time.time()
            while self.env.time < self.env.scenario.start_time + self.sim_time:
                if self.animate:
                    self.env.render()
                # get_action
                action = self.controller.policy(obs, reward, done, **info)
                # print(action)
                # step
                n_obs, reward, done, info = self.env.step(action)

                # next_state = np.reshape(next_state, [1, state_size])
                # 에피소드가 중간에 끝나면 -100 보상
                # ??????reward = reward if not done or score == 499 else -100

                # 리플레이 메모리에 샘플 <s, a, r, s'> 저장
                self.controller.append_sample(obs.CGM, action, reward, n_obs.CGM, done)
                # 매 타임스텝마다 학습
                if len(self.controller.memory) >= self.controller.train_start:
                    self.controller.train_model()
                    print("time")
                obs = n_obs
                if obs.CGM < 50:
                    print("Hypoglycemia")
                    break
                elif obs.CGM > 250:
                    print("Hyperglycemia")
                    break
            toc = time.time()
            print('Simulation took episode {} seconds.'.format(toc - tic))
        totaltoc = time.time()
        print('Simulation took total {} seconds.'.format(totaltoc - totaltic))

    def results(self):
        return self.env.show_history()

    def save_results(self):
        df = self.results()
        if not os.path.isdir(self.path):
            os.makedirs(self.path)
        filename = os.path.join(self.path, str(self.env.patient.name) + '.csv')
        df.to_csv(filename)

    def reset(self):
        self.env.reset()
        self.controller.reset()


def sim(sim_object):
    print("Process ID: {}".format(os.getpid()))
    print('Simulation starts ...')
    sim_object.simulate()
    sim_object.save_results()
    print('Simulation Completed!')
    return sim_object.results()


def batch_sim(sim_instances, parallel=False):
    tic = time.time()
    if parallel and pathos:
        with Pool() as p:
            results = p.map(sim, sim_instances)
    else:
        if parallel and not pathos:
            print('Simulation is using single process even though parallel=True.')
        results = [sim(s) for s in sim_instances]
    toc = time.time()
    print('Simulation took {} sec.'.format(toc - tic))
    return results
