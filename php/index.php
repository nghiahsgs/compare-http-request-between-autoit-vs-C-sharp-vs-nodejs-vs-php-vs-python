<?php

$head='';
function get_url()
{
  $ch = curl_init();
  curl_setopt($ch, CURLOPT_URL, 'http://google.com');
  curl_setopt($ch, CURLOPT_HEADER, TRUE);
  curl_setopt($ch, CURLOPT_NOBODY, TRUE); // remove body
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);

  $head = curl_exec($ch);

  // echo $head."<br>";
  // $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);

}

$time_1=time();
for ($i=0; $i <10 ; $i++) { 
  get_url();
}
$time_2=time();



echo ($time_2-$time_1)/10;
?>