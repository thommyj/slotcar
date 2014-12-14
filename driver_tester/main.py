#!/usr/bin/python
import matplotlib.pyplot as plt
import numpy as np
import time


def error(msg):
    #print '\033[31;1mError: \033[0;31m{0}\033[0m'.format(msg)
    pass


# Structure representing a driver packet
class driver_packet():
    def __init__(self, data):
        self.raw = data
        self.brake       = data >> 7 & 0x01
        self.lane_change = data >> 6 & 0x01
        self.power       = data >> 0 & 0x3F

    def __str__(self):
        return '{0} {1} {2}' \
            .format(self.brake, self.lane_change, self.power)

# Strucutre representing the led_status
class led_status():
    def __init__(self, data):
        self.raw = data
        self.green       = data >> 7 & 0x01
        self.red         = data >> 6 & 0x01
        self.other       = data >> 0 & 0x3F

    def get_game_status(self):
        if (self.green == 1 and self.red == 0):
            return "Started"
        elif (self.green == 1 and self.red == 1):
            return "Stopped/Reset"
        else:
            return "Unknown"

    def __str__(self):
        return '{0} {1} {2} {3}' \
            .format(self.green, self.red, hex(self.other), self.get_game_status())


#
##
# Structure representing one packet sent to the Slotcar track
##
#
class to_track():
    def __init__(self, data):
        self.raw = data
        self.oper_mode = data[0]
        self.dp = range(6)
        for i in range(6):
            self.dp[i] = driver_packet(data[i])
        self.led_status = led_status(data[7])
        self.chksum = data[8]

    def validate_operation_mode(self):
        if(self.oper_mode != 0xFF):
            error('Failed to receive packet from track (got: {0})'.format(hex(self.oper_mode)))

    def __str__(self):
        ret = 'Oper mode: {0}\n'.format(hex(self.oper_mode))
        ret += '     B L Pwr\n'
        for idx, p in enumerate(self.dp):
            ret += 'DP{0}: {1}\n'.format(idx + 1, str(p))
        ret += '     R G other\n'
        ret += 'Led: {0}\n'.format(self.led_status)
        ret += 'Chksum: {0}\n'.format(hex(self.chksum))
        return ret


# Structure representing the handset and track status
class track_status():
    def __init__(self, data):
        self.raw = data
        if (data >> 7 & 0x01 == 0):
            error('The track status byte (1:st) should have bit 7 set to 1 ({0:#x}, {1:08b})'.format(data,data))

        self.handset      = data >> 1 & 0x3F
        self.power_status = data >> 0 & 0x01

    def __str__(self):
        return '{0:b} {1}' \
            .format(self.handset, self.power_status)

# Structure representin the car_id byte
class car_id():
    def __init__(self, data):
        self.raw = data
        self.car_id = data & 0x7

        if (~(data | 0x7) != 0):
            error('The Car id byte (9:th) should have the rightmost 5 bits set to 1 ({0:#x}, {0:08b})'.format(data))
        if (self.car_id == 7):
            error('The Car id byte (9:th) has invalid value (7)({0:#x}, {0:08b})'.format(data))
    def __str__(self):
        return '{0}'.format(self.car_id)


# Structure representin the car_id byte
class game_time():
    def __init__(self, data):
        self.raw = data
        self.timer = \
            data[0] << 24 | \
            data[1] << 16 | \
            data[2] << 8  | \
            data[3]

        if (self.timer == 0xFFFFFFFF):
            error('Car id invalid or game not started (invalid timer)')

    def __str__(self):
        sec = self.timer * 6.4 /1000000
        return '{0} s'.format(sec)


#
##
# Structure representing one packet sent from the Slotcar track
##
#
class from_track():
    def __init__(self, data):
        self.track_status = track_status(data[0])
        self.handset = range(6)
        for i in range(6):
            self.handset[i] = driver_packet(data[i])
        self.current = data[7]
        self.car_id = car_id(data[8])
        self.game_time = game_time(data[9:13])

    def __str__(self):
        ret = 'Track Status: {0}\n'.format(self.track_status)
        ret += '     B L Pwr\n'
        for idx, p in enumerate(self.handset):
            ret += 'DP{0}: {1}\n'.format(idx + 1, str(p))

        ret += 'Current: {0} mA\n'.format(float(self.current)/255)
        ret += 'Car ID: {0}\n'.format(self.car_id)
        ret += 'Time: {0}\n'.format(self.game_time)
        return ret

#
##
# The contents of the Register file in the FPGA
##
#
class rf_contents():
    def __init__(self, raw_data_string):
        data = list(raw_data_string)

        for i in range(len(data)):
            data[i] = ord(data[i])

        self.to_track = to_track(data[0:9])
        self.from_track = from_track(data[9:23])

        self.to_track.validate_operation_mode()

    def __str__(self):
        ret = '{0}\n'.format(self.to_track)
        ret += '{0}\n'.format(self.from_track)
        return ret










class plotter():

    def __init__(self, name, ylabel, color, size, size_x, size_y, which):
        self.name = name
        self.ylabel = ylabel
        self.color = color
        self.size = size
        self.x = range(size)
        self.values = [0] * size

        self.figure = plt.figure(name)
        self.ax = self.figure.add_subplot(size_x, size_y, which)
        plt.ylabel(self.ylabel)

        self.plot = self.ax.plot(self.x, self.values, color=self.color, animated=True)[0]

    def add_measurement(self, value):
        self.values.pop(0)
        self.values.append(value)
    def update(self):
        self.plot.set_ydata(self.values);
        self.ax.relim()
        self.ax.autoscale_view(True,True,True)









driver_path = "test.txt"

print "Starting..."


throttle_plot = range(6)
throttle_plot2 = range(6)

for i, thr in enumerate(throttle_plot):
    throttle_plot[i] = plotter('Throttle','Handset' + str(i), 'r', 100, 6, 1, i);
    throttle_plot2[i] = plotter('Throttle','Handset' + str(i), 'b', 100, 6, 1, i);

current_plot = plotter('Current', '[mA]', 'b', 100, 1, 1, 1);

import sys
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np


with open(driver_path, "r") as driver:
    def animate(iteration):
        #print iteration

        plots = []

        raw_rf_content = driver.read(22)
        if (len(raw_rf_content) < 22):
            error("Not enough data, exiting")
            driver.seek(0,0)
            return []
            sys.exit(0)
        contents = rf_contents(raw_rf_content)


        if (False):
            print contents
            return []


        current_plot.add_measurement(contents.from_track.current);
        current_plot.update()
        plots.append(current_plot.plot)

        for i, thr in enumerate(throttle_plot):
            thr.add_measurement(contents.from_track.handset[i].power)
            thr.update()
            plots.append(thr.plot)

        for i, thr in enumerate(throttle_plot2):
            thr.add_measurement(contents.to_track.dp[i].power)
            thr.update()
            plots.append(thr.plot)

        return plots

    ani = animation.FuncAnimation(current_plot.figure,
                                  animate,
                                  xrange(1, 2), 
                                  interval=1,
                                  blit=True)

    plt.show()

print "Closing..."
