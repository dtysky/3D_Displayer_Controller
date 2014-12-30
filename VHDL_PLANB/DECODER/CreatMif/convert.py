fout=open('../ROM.mif','w')
fout.write('WIDTH=16;\nDEPTH=8096;\nADDRESS_RADIX=UNS;\nDATA_RADIX=BIN;\nCONTENT BEGIN\n')
pointstxt=open('mifsource.txt','r').read()

points=[[]]
whole=0
so=''
i=0

for p in pointstxt.splitlines():
	x,y=p.split(' ')
	x=int(x)
	y=int(y)
	if x==0 and y==0:
		i+=1
		points.append([])
	else:
		points[i].append((y,x))
points.pop()

for squ in points:
	squ=sorted(squ)
	for p in squ:
		if p[1]<0 or p[1]>120:
			continue
		x=bin(p[1])[2:]
		y=bin(p[0])[2:]
		for i in range(7-len(x)):
			x='0'+x
		for i in range(7-len(y)):
			y='0'+y
		so+='\t'+str(whole)+'  :   00'+str(x)+str(y)+';\n'
		whole+=1
	so+='\t'+str(whole)+'  :   1100000000000000;\n'
	whole+=1

fout.write(so)
fout.write('\t['+str(whole)+'..8095]  :   0;\nEND;')

fout.close()