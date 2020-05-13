

import numpy as np
import math
import matplotlib.pyplot as plt

class Line:
    def __init__(self, x1, x2, slope, b):
        self.x1 = x1
        self.x2 = x2
        self.slope = slope
        self.b = b

def sigmoid(x):
    return 1.0 / (1.0 + math.exp(-x))

def graph(lines, plot_sigmoid, plot_tanh):
    overall_x = np.linspace(-6, 6, 500)
    piecewise = []


    fig, ax = plt.subplots()
    ax.tick_params(axis='both', which='major', labelsize=28)
    ax.tick_params(axis='both', which='minor', labelsize=28)

    for line in lines:
        x = np.linspace(line.x1, line.x2, math.floor((line.x2-line.x1)*500))
        y = (line.slope * x) + line.b
        piecewise.append(y)
        plt.plot(x, y, 'r')

    if plot_sigmoid:
        overall_y = 1.0 / (1.0 + np.exp(-overall_x))
    elif plot_tanh:
        overall_y = np.tanh(overall_x)

    plt.plot(overall_x, overall_y, 'b')

    plt.show()

if __name__ == '__main__':
    
    plot_sigmoid = int(input("Input 1 for sigmoid, 0 for tanh: ")) == 1
    plot_tanh = not plot_sigmoid
    if plot_sigmoid:
        operation = sigmoid
    else:
        operation = math.tanh
    
    lines = []
    x2 = input("Input the first x-value: ")
    if (x2 == ''):
        valid = False
    else:
        valid = True

    x2 = float(x2)

    while valid:
        x1 = x2
        x2 = input("Input next x-value: ")
        if (x2 == ''):
            break
        x2 = float(x2)

        slope = (operation(x2) - operation(x1)) / (x2 - x1)
        b = operation(x1) - slope * x1
        lines.append(Line(x1, x2, slope, b))

    for i in lines:
        print("y = " + str(i.slope) + " * x + " + str(i.b))

    graph(lines, plot_sigmoid, plot_tanh)


