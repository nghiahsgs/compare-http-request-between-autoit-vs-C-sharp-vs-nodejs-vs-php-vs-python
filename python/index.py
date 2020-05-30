import requests
import time
import io
def write_file(file_name,data):
  f=io.open(file_name,mode='w',encoding='utf-8')
  f.write(data)
  f.close()

t1=time.time()

for i in range(10):
  res=requests.get('http://google.com')

t2 = time.time()
write_file('code.html', res.text)

print('total time',(t2-t1)/10, 'seconds')


