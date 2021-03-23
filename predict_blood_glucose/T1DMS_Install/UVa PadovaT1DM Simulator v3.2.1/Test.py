import matlab.engine

print(matlab.engine.find_matlab())

print('start matlab!')
eng = matlab.engine.start_matlab()
print('connect to matlab')

eng.set_param('testing_platform/STD_Treat_v3_2', 'glucose',20 , 'meal announcemet',1 , 'ToD', 0 , 'Glucogan injection',1 ,'pramlintide injection',1, 'insulin injection', 1)




