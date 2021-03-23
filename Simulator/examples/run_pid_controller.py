from simglucose.controller.pid_ctrller import PIDController
from simglucose.simulation.user_interface import simulate


pid_controller = PIDController(P=0.06, I=0.00007, D=0.0001, target=140)
# pid_controller = PIDController(P=0, I=1, target=140)
s = simulate(controller=pid_controller)
# s = simulate()

