using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using xNet;

namespace test_speed_http_request
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {

            Int32 time_1= (Int32)(DateTime.UtcNow.Subtract(new DateTime(1970, 1, 1))).TotalSeconds;

            for (int i = 0; i < 10; i++) {
            
            HttpRequest http = new HttpRequest();
            http.Cookies = new CookieDictionary();
            http.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36";
            // httpLogin2.AddHeader("cookie", cookie);
            string response = http.Get("http://google.com").ToString();
            //string fb_dtsg = Regex.Match(htmlLogin3, "name=\"fb_dtsg\" value=\"(.*?)\"").Groups[1].ToString();

            
            }
            Int32 time_2 = (Int32)(DateTime.UtcNow.Subtract(new DateTime(1970, 1, 1))).TotalSeconds;

            
            float total_time = (float.Parse(time_2.ToString()) - float.Parse(time_1.ToString())) / 10.0f;



            MessageBox.Show(total_time.ToString());

        }

        private void button2_Click(object sender, EventArgs e)
        {
            Int32 unixTimestamp = (Int32)(DateTime.UtcNow.Subtract(new DateTime(1970, 1, 1))).TotalSeconds;
            MessageBox.Show(unixTimestamp.ToString());
        }
    }
}
