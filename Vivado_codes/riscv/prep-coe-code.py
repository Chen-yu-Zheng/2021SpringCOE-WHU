# L = ["0xGeeks\n", "0xfor\n", "0xGeeks\n"]
 
# Using readlines()
file1 = open('studentnosorting.dat', 'r')
Lines = file1.readlines()

# # writing to file
file2 = open('studentnosorting.coe', 'w')

file2.writelines("memory_initialization_radix=16;\n")
file2.writelines("memory_initialization_vector=\n")

count = 0
# Strips the newline character
for line in Lines:
#    count += 1
#    print("{}".format(line.strip()[2:10]))
	if count == 0:
		file2.writelines("{}".format(line[0:8]))
		count = 1
	else:
		file2.writelines(",\n{}".format(line[0:8]))
    
file2.writelines(";")

file1.close()
file2.close()