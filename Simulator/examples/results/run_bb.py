from simglucose.controller.basal_bolus_ctrller import  BBController
from simglucose.simulation.user_interface import simulate


bb_Controller = BBController()
s = simulate(controller=bb_Controller)