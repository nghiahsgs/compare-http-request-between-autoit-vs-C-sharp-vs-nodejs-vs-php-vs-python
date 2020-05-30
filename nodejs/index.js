const axios = require('axios');





const getRequest= async ()=>{
  // Make a request for a user with a given ID
  try {
    const response = await axios.get("http://google.com");  
    return response;
  } catch (error) {
    return error;
  } 
}

const main=async ()=>{

  const t1 = Date.now() / 1000;
  let kq=''
  for (let index = 0; index < 10; index++) {
    kq = await getRequest();
  }
  // console.log(kq)
  
  const t2 = Date.now() / 1000;

  console.log("total time", (t2 - t1) / 10, "seconds");
}

main()