# Synchronize the accelerometer and gyroscope data  

import sys
import pandas as pd
import numpy as np

# Read data
path=sys.argv[1]
if path[-1] != '/' or path[-1] != '\\':
    path = path + '/'
path_accel= path + 'Accel.txt'
acc=( pd.read_csv(path_accel,names=list('tabc')))
path_gyro= path + 'Gyro.txt'
gyro=( pd.read_csv(path_gyro,names=list('tabc')))
g=[]
a=[]
t=acc[list('t')].values

G = 9.81
for c in 'abc':
    acc[list(c)] = G*acc[list(c)]

# Make imu
for c in 'abc':
    g.append(np.interp(acc[list('t')].values[:, 0], gyro[list('t')].values[:, 0], gyro[list(c)].values[:, 0]))
    a.append(acc[list(c)].values)
M=np.column_stack((t,g[0],g[1],g[2],a[0],a[1],a[2]))

full = M[M[:,0].argsort()]
path= path + 'accel-gyro.txt'
np.savetxt(path, full, delimiter=",",fmt='%.6f')
