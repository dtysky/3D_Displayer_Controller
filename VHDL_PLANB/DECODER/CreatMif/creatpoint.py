import re

fin=open('pointsource.txt','r')
fout=open('point.dat','w')

sa=[]
res=''
i=0

for s in fin.read().splitlines():
	if s=='':
		i+=1
		res+='p('+str(i)+',:,:)=['
		tmp=re.match(r'X=  (.+)  Y=  (.+)  Z=  (.+)',sa[0])
		res+='['+tmp.group(1)+','+tmp.group(2)+','+tmp.group(3)+'];'
		tmp=re.match(r'X=  (.+)  Y=  (.+)  Z=  (.+)',sa[1])
		res+='['+tmp.group(1)+','+tmp.group(2)+','+tmp.group(3)+']];\n'
		sa=[]
	else:
		sa.append(s)



fout.write(res)
fout.close()