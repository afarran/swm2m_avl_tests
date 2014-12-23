# just copy/paste output of 'prop list AVL' to props.txt and run this script
# then add new avlMaper to AvlDebuger
data = file("props.txt").readlines()
print ("self.avlMaper = {}")
for item in data:
  splt = item.split()[1].split('=')[1].split('(')
  print ("self.avlMaper[%s] = \"%s\""%(splt[0],splt[1][:-1]))
