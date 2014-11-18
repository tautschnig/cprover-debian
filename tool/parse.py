
import os,sys,xml.etree.ElementTree as et
#findFailure for an assignment and return base_name, value, location, file name and line
def findFailure(root):
	for trace in root.iter('goto_trace'):#find goto_trace tag(so we won't search the whole root)
		for assign in trace.iter('assignment'):#find assignment tag
			stepAssign = int(assign.get('step_nr'))#step nr of assignment tag
			name = assign.find('base_name').text
			value = assign.find('value').text
			location = assign.find('location')
			if location is not None: 
				file = location.get('file')
				line = location.get('line')
			#find failure for specific assignment(step nr of failure must be assignment step nr + 2)
			for failure in trace.iter('failure'):
				stepFail = int(failure.get('step_nr'))
				#if it has a failure, it must have the step nr +2
				if(stepFail == stepAssign+2):
					return [name,value,file,line]
#-----------------END findFailure(root) --------------------------------------------------

fileName = sys.argv[1]

os.system("cbmc --xml-ui "+fileName+".c > "+fileName+".counterexample.xml")
os.system("gcc -g "+fileName+".c -o"+fileName)

#read counterexample
tree = et.parse(fileName+".counterexample.xml")
root = tree.getroot()

#find a failure
list = findFailure(root)
#start gdb
#os.system("gdb ./"+file.replace('.c', ''))

#save to file in this order: variable name, value, file name, line number
file = open("info.txt","w")
for element in list:
	file.write(element+"\n")
file.close()

 









	
	
