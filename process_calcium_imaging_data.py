####################

#!/usr/local/bin/python
'''
author:    Csaba Veraszto
date:       02/12/14
content:  Ca-imaging script, calculates dF/F. Before running one has to set the home, the name of the neuron (for later identification plus data will be saved with this name), the fps (timerate) which can be found in the input filename and based on this and firing activity you have to choose 
the amount of frames the script will average and calculate the minimum from to get Fo. The second part of the script plots original and calculated data, and you have the option to plot different dF/Fs in one plot too. Make sure you edit the plot labels accordingly.
'''


aver_range = 12 #Change: average over #frames around each value
min_range = 20 #Change:  seek out the minimum value from the #frames before the current one
neuron_in_question = "neuron1"      #Change
source_filename = "video1.txt"	 #Change
output_filename = "Activity_" + neuron_in_question + ".txt"
timerate = 0.5     #Change
titel = neuron_in_question + ' activity with ' + str(round(1/timerate, 2)) + ' fps'

import numpy as np
import os
from os import chdir
os.chdir("/your/directory/")   #Change: where to look for your measurements
a = np.genfromtxt(source_filename , usecols=[1], skip_header=1)

def boxcar_filter(a, box_size=aver_range):
    import numpy as np
    box = np.ones(box_size, float) / box_size
    aboxed = np.convolve(a, box, mode='valid')
    return aboxed

aboxed = boxcar_filter(a, box_size=aver_range)

#Cutting off the edges, used for averaging. 
a = a[aver_range/2:-(aver_range/2)+1]


#Find minimum in the averaged data
mina = aboxed
for x in (np.arange(min_range)+1):
	b = np.roll(aboxed, x)
	mina = np.minimum(mina, b)
	

#Trimming elements affected by boundary effect
a = a[min_range:]
mina = mina[min_range:]
aboxed = aboxed[min_range:]


#Calculating Fo 
f = a-mina

#dF/F calculation
df = np.divide(f, mina)
dfp = np.multiply(df,100) #Multiplied by 100 
#print dfp
np.savetxt(output_filename, dfp, fmt='%10.5f', delimiter=', ', newline='\n', header='', footer='')

#Plotting 
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
fig.suptitle(titel)
ax.set_yticklabels([])
#ax.plot(np.arange(len(a)), a, label='Original', linewidth=2)
#ax.plot(np.arange(len(mina)), mina, label='Minimum', linewidth=2)
ax.plot(np.arange(len(dfp)), dfp, label='new df', linewidth=2)
#ax.plot(np.arange(len(aboxed)), aboxed, label='Averaged', linestyle='--')
ax.set_xlabel('Frames', fontsize=12)
ax.set_ylabel(u"\u0394"'F/F', fontsize=12)
ax.legend(loc=1)
plt.ion()
plt.show()

print(dfp)

####################
