from simglucose.controller.dqlearnctrller import DQLController
from simglucose.simulation.user_interface import simulate
from simglucose.controller.pid_ctrller import PIDController

controller = PIDController(state_size=1, action_size=3, episode=20, previous_time=4, model='g')
s = simulate(controller=controller, sim_time=24, animate=True, parallel=False, name='', selection=1, seed=0, start_time=0, cgm_selection=2, pump_selection=2)

