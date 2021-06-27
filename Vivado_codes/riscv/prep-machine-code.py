# Python code to
# demonstrate readlines()
 
# L = ["0xGeeks\n", "0xfor\n", "0xGeeks\n"]
 
# Using readlines()
file1 = open('test_0x.dat', 'r')
Lines = file1.readlines()

# # writing to file
file2 = open('riscv32_sim6.dat', 'w')
 
#count = 0
# Strips the newline character
for line in Lines:
#    count += 1
#    print("{}".format(line.strip()[2:10]))
    file2.writelines("{}\n".format(line[2:10]))

file1.close()
file2.close()