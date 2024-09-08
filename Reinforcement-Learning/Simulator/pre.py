from keras.models import Sequential
from keras.layers.core import Dense

import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder

health = pd.read_csv('strokecsv/healthcare-dataset-stroke-data.csv')
le = LabelEncoder()
health[health.select_dtypes(include=['object']).columns] = health[health.select_dtypes(include=['object']).columns].apply(le.fit_transform)
health.head()

print(health.head())
health = np.array(health)

X = np.array(health[:,1:11])
Y = np.array(health[:,11])
print(X)
model = Sequential()
model.add(Dense(24,  input_dim=10, activation='relu'))
model.add(Dense(10, activation='relu'))
model.add(Dense(1, activation='sigmoid'))

# 모델 컴파일
model.compile(loss='mean_squared_error',
            optimizer='adam',
            metrics=['accuracy'])

# 모델 실행
model.fit(X, Y, epochs=200, batch_size=500)

print()
print(model.predict(np.array([0.0, 90.0, 0.0, 0.0, 0.0, 0.0, 0.0, 200.0, 40.0, 0.0]).reshape(1,10)))
