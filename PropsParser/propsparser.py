data = file("props.txt").readlines()

print ("self.avlMaper = {}")

for item in data:
  splt = item.split()[1].split('=')[1].split('(')
  print ("self.avlMaper[%s] = \"%s\""%(splt[0],splt[1][:-1]))
