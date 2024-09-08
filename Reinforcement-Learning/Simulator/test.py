from keras.models import Sequential
from keras.layers.core import Dense
from sklearn.preprocessing import LabelEncoder

import pandas as pd
import numpy as np
import tensorflow as tf

# seed 값 설정
np.random.seed(3)
tf.random.set_seed(3)

# 데이터 입력
df = pd.read_csv('strokecsv/healthcare-dataset-stroke-data.csv', header=None)

# 데이터 개괄 보기
# print(df.info())

# 데이터의 일부분 미리 보기
# print(df.head())

dataset = df.values
# gender
XG = dataset[1:,1]
e = LabelEncoder()
e.fit(XG)
XG = e.transform(XG)

# age
XA = dataset[1:,2]

# hypertension
XH = dataset[1:,3]

# heart_disease
XHD = dataset[1:,4]

# ever_married
XEM = dataset[1:,5]
e = LabelEncoder()
e.fit(XEM)
XEM = e.transform(XEM)

# work_type
XW = dataset[1:,6]
e = LabelEncoder()
e.fit(XW)
XW = e.transform(XW)

# Residence_type
XR = dataset[1:,7]
e = LabelEncoder()
e.fit(XR)
XR = e.transform(XR)

# avg_glucose_level
XAG = dataset[1:,8]

# bmi
XB = dataset[1:,9]

# smoking_status
XS = dataset[1:,10]
e = LabelEncoder()
e.fit(XS)
XS = e.transform(XS)

Y = dataset[1:,11]

print("gender"+str(XG))
print("ever_married"+str(XEM))
print("bmi"+str(XB))
print("smoking"+str(XS))
print()

# df1 = pd.DataFrame([XG,XA],columns=['g','a'])
# df.to_csv('tt.csv', index=False)

XG = np.array(XG).reshape(1,5110)
XA = np.array(XA).reshape(1,5110)
XH = np.array(XH).reshape(1,5110)
XHD = np.array(XHD).reshape(1,5110)
XEM = np.array(XEM).reshape(1,5110)
XW = np.array(XW).reshape(1,5110)
XR = np.array(XR).reshape(1,5110)
XAG = np.array(XAG).reshape(1,5110)
XB = np.array(XB).reshape(1,5110)
XS = np.array(XS).reshape(1,5110)
X = np.concatenate([XG,XA,XH,XHD,XEM,XW,XR,XAG,XB,XS],axis=0)

X = X.T

X = np.asarray(X).astype(np.float32)

# 문자열 변환

# print(Y)
Y = np.array(Y).reshape(1,5110).astype(np.float32)

print(X.shape)
print(Y.shape)
# 모델 설정
model = Sequential()
model.add(Dense(30,  input_dim=10, activation='relu'))
model.add(Dense(30, activation='relu'))
model.add(Dense(1, activation='sigmoid'))

# 모델 컴파일
model.compile(loss='mean_squared_error',
            optimizer='adam',
            metrics=['accuracy'])

# 모델 실행
model.fit(X, Y, epochs=200, batch_size=1.)
test = np.array([1,31,0,1,0,0,200,23,1])
# 결과 출력
# p = model.predict(test.astype(np.float32))
# print(p)