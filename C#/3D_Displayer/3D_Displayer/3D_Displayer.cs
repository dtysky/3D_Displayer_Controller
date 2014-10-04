// PC application for this system.
// copyright(c) 2014 dtysky

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

///////////////////////////////////////////////////////////////////

using CyUSB;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System;
using System.IO;
using System.Threading;
using System.Windows.Threading;

namespace TD_Displayer
{
    class Usb
    {

        USBDeviceList MyUsbList;
        CyUSBDevice MyUsb;
        CyUSBEndPoint MyOutPoint;
        CyUSBEndPoint MyInPoint;
        CyControlEndPoint MyControlPoint;
        CyFX2Device Fw;

        public Usb()
        {
            while(true)
            {
                MyUsbList = new USBDeviceList(CyConst.DEVICES_CYUSB);
                if (MyUsbList.Count == 0)
                    MessageBox.Show("把人家插上啦~");
                else
                    break;
            }
        }

        public bool Down_Fw(String Fw_Path)
        {
            bool Success;
            Fw = MyUsbList["Cypress FX2LP Sample Device"] as CyFX2Device;
            if (Fw != null)
            {
                Success = Fw.LoadRAM(Fw_Path);
            }
            else
            {
                Fw = MyUsbList["Cypress FX2LP StreamerExample Device"] as CyFX2Device;
                Success = Fw.LoadRAM(Fw_Path);
            }
            return Success;
        }

        public bool ReConnect()
        {
            MyUsb = MyUsbList[0x04B4, 0x1004] as CyUSBDevice;
            if (MyUsb != null)
            {
                MyUsb.ReConnect();
                MyUsb = MyUsbList[0x04B4, 0x00F1] as CyUSBDevice;
            }
            else
            {
                MyUsb = MyUsbList[0x04B4, 0x00F1] as CyUSBDevice;
            }
            if (MyUsb != null)
            {
                MyOutPoint = MyUsb.EndPointOf(0x02);
                MyInPoint = MyUsb.EndPointOf(0x86);
                MyControlPoint = MyUsb.ControlEndPt;
                Reset();
                return true;
            }
            else
            {
                return false;
            }
        }


        public bool Trans(int len, byte[] data)
        {
            bool Success = true;
            Success = MyOutPoint.XferData(ref data, ref len);
            if (!Success)
            {
                uint Lastf = MyOutPoint.LastError;
            }
            return Success;
        }

        public bool Collect(int len, byte[] data)
        {
            bool Success;
            Success = MyInPoint.XferData(ref data, ref len);
            if (!Success)
            {
                uint Lastf = MyOutPoint.LastError;
            }
            return Success;
        }

        public void Reset()
        {
            MyControlPoint.Direction = CyConst.DIR_TO_DEVICE;
            MyControlPoint.ReqType = CyConst.REQ_VENDOR;
            MyControlPoint.ReqCode = 0xFF;
            MyControlPoint.Target = CyConst.TGT_DEVICE;
            MyControlPoint.Index = 0x00;
            MyControlPoint.Value = 0x00;

            int i = 0;
            byte[] Rst = new byte[i];
           
            while(true)
                if (MyControlPoint.XferData(ref Rst,ref i))
                {
                    break;
                }
                
            
            Thread.Sleep(1);

            MyInPoint.Abort();
            MyInPoint.Reset();
            MyInPoint.Abort();
            MyOutPoint.Reset();
        }

        public void SetOutTime(String IO , uint value)
        {
            if (IO == "In")
            {
                MyInPoint.TimeOut = value;
            }
            else if( IO == "Out" )
            {
                MyOutPoint.TimeOut = value;
            }
        }

    }


    class Winx:Window
    {

        Usb Usb_Mine;
        Window MyWin;
        Canvas MyCanvas;
        TextBox t_tital;
        TextBox t_statuses;
        TextBox trans_t;
        Button b_ok;
        Button b_quit;
        Button usb_check;
        Button usb_down;
        Button b_collect;
        ProgressBar trans_bar;
        Thread Trans;
        Thread Collect;

        public Winx()
        {
            Usb_Mine = new Usb();

            MyWin = new Window();
            MyCanvas = new Canvas();
            t_tital = new TextBox();
            t_statuses = new TextBox();
            trans_t = new TextBox();
            b_ok = new Button();
            b_quit = new Button();
            usb_check = new Button();
            usb_down = new Button();
            b_collect = new Button();
            trans_bar = new ProgressBar();
        }

        public delegate void MyInvoke_T(String str);
        public delegate void MyInvoke_B(int value);
        public void Refresh_Text(String value){trans_t.Text = value;}
        public void Refresh_Bar(int value ){trans_bar.Value = value;}

        void Onclick_Quit(object sender, EventArgs e)
        {
            if (!(Trans==null))
                Trans.Abort();

            if (!(Collect==null))
                Collect.Abort();

            Application.Current.Shutdown();
            this.Dispatcher.BeginInvokeShutdown(DispatcherPriority.Normal);
        }

        void Onclick_Download(object sender, EventArgs e)
        {
            if (Usb_Mine.Down_Fw( "slave.hex"))
                MessageBox.Show("换装成功～");
            else
                MessageBox.Show("没有东西人家怎么穿啊！");
        }

        
        void Onclick_Trans(object sender, EventArgs e)
        {
            Trans = new Thread(new ThreadStart(Onclick_Transx));
            Trans.Start();
        }

        void Onclick_Transx()
        {
            
            if (!Usb_Mine.ReConnect())
            {
                MessageBox.Show("人家还没有没有准备好啦，笨蛋！");
            }
            else
            {

                bool Success = true;
                bool Trans_Ack = true;
                byte[] Trans_Matrix = new byte[0];
                byte[] Trans_Buffer = new byte[512];
                int Trans_No = 0;
                byte[] Trans_No_B = new byte[4];
                FileStream Image_Matrix_add = new FileStream(".//3D_Martix.txt", FileMode.Open);
                BinaryReader Image_Matrix = new BinaryReader(Image_Matrix_add);

                Trans_Matrix = Image_Matrix.ReadBytes(Convert.ToInt32(Image_Matrix.BaseStream.Length));
                int Trans_Matrix_len = Trans_Matrix.Length / 512;
                int Trans_Matrix_Rem = Trans_Matrix.Length % 512;

                MyInvoke_B Re_B = new MyInvoke_B(Refresh_Bar);
                MyInvoke_T Re_T = new MyInvoke_T(Refresh_Text);

                Random ra = new Random(65535);
                byte[] rai = new byte[2];

                Usb_Mine.SetOutTime("In" , 2);
                Usb_Mine.SetOutTime("Out", 2);
                this.Dispatcher.BeginInvoke(Re_T, "世界线变动中......\n           "+"0.00"+"%");
                int TransTime_S = System.Environment.TickCount;

                for (int i = 0; i < Trans_Matrix_len ; i++)
                {
                    int a = 0;
                    int b = 0;
                    ra.NextBytes(rai);
                    Trans_No_B =BitConverter.GetBytes(Trans_No);

                    if (i < Trans_Matrix_len)
                    {
                        for (int j = 0; j < 512; j++)
                        {
                            if (j == 0)
                                Trans_Buffer[j] = 0xA0;
                            else if (j == 1)
                                Trans_Buffer[j] = 0x81;
                            else if( j == 2 )
                                Trans_Buffer[j] = 0x00;
                            else if (j == 3)
                                Trans_Buffer[j] = 0x41;
                            else if( j < 8 )
                                Trans_Buffer[j] = Trans_No_B[j - 4];
                            else if(j<510)
                            {
                                //Trans_Buffer[j] = Trans_Matrix[i * 2040 + j - 8]

                                if(b==1)
                                {
                                    if (a==255)
                                    {
                                        a = 0;
                                    }
                                    else
                                    {
                                        a++;
                                    }
                                    b = 0;
                                    //a = 255;
                                    Trans_Buffer[j] = Convert.ToByte(a);
                                }
                                else
                                {
                                    b ++;
                                    //a = 0;
                                    Trans_Buffer[j] = Convert.ToByte(0);
                                }
                            }
                            else
                                Trans_Buffer[j] = Convert.ToByte(rai[j-510]);

                        }
                    }
                    /*else if (i == Trans_Matrix_len)
                    {
                        for (int j = 0; j < Trans_Matrix_Rem; j++)
                        {
                            if (j == 0)
                                Trans_Buffer[j] = 0xA0;
                            else if (j == 1)
                                Trans_Buffer[j] = 0x81;
                            else if (j == 2)
                                Trans_Buffer[j] = 0x00;
                            else if (j == 3)
                                Trans_Buffer[j] = 0x80;
                            else if (j < 8)
                                Trans_Buffer[j] = Trans_No_B[j - 4];
                            else
                                Trans_Buffer[j] = Trans_Matrix[i * 2040 + j - 8];
                        }
                        for (int j = Trans_Matrix_Rem; j < 2040; j++)
                            Trans_Buffer[j] = 0x00;
                    }*/
                    

                    Success = Usb_Mine.Trans(512, Trans_Buffer);

                    if (Success)
                    {
                        Trans_Ack = Usb_Mine.Collect(2, Trans_Buffer);
                        if (!Trans_Ack)
                        {
                            i --;
                            Usb_Mine.Reset();
                        }
                        else
                        {
                            if(rai[0]==Trans_Buffer[0] && rai[1]==Trans_Buffer[1])
                            {
                                Trans_No ++;
                            }
                            else
                            {
                                i--;
                                Usb_Mine.Reset();
                            }
                        }
                    }
                    else
                    {
                        i--;
                        Usb_Mine.Reset();
                    }

                    this.Dispatcher.BeginInvoke(Re_B, Trans_No * 100 / Trans_Matrix_len);
                    this.Dispatcher.BeginInvoke(Re_T, "世界线变动中......\n           " + Convert.ToString(Trans_No * 100.0 / Trans_Matrix_len) + "%");

                }

                int TransTime_E = System.Environment.TickCount;

                Image_Matrix.Close();
                Image_Matrix_add.Close();
                this.Dispatcher.BeginInvoke(Re_T, "世界线偏斜速率\n              " + Convert.ToString(Trans_Matrix.Length * 1000.0 / (TransTime_E - TransTime_S) / 1048576 ) + "MB/s");
                Trans.Abort();

            }

        }

        void Onclick_Collect(object sender, EventArgs e)
        {
            Collect = new Thread(new ThreadStart(Onclick_Collectx));
            Collect.Start();
        }

        void Onclick_Collectx()
        {
            bool Success = true;
            byte[] Trans_Matrix = new byte[0];
            byte[] Trans_Buffer = new byte[2048];
            byte[] Collect_Buffer1 = new byte[512];
            byte[] Collect_Buffer2 = new byte[512];
            byte[] Collect_Buffer3 = new byte[512];
            byte[] Collect_Buffer4 = new byte[512];
            int Trans_No = 0;
            byte[] Trans_No_B = new byte[4];
            Trans_No_B = BitConverter.GetBytes(5);
            FileStream Image_Matrix_add = new FileStream(".//in_test.txt", FileMode.Create);
            BinaryWriter Image_Matrix = new BinaryWriter(Image_Matrix_add); ;

            MyInvoke_T Re_T = new MyInvoke_T(Refresh_Text);
            MyInvoke_B Re_B = new MyInvoke_B(Refresh_Bar);

            Usb_Mine.SetOutTime("In", 3);
            Usb_Mine.SetOutTime("Out", 3);

            this.Dispatcher.BeginInvoke(Re_T, "世界线回调中......");

            int TransTime_S = System.Environment.TickCount;

            for (int i = 0; i < 1000; i++)
            {

                while (true)
                {
                    for (int j = 0; j < 8; j++)
                    {
                        if (j == 0)
                        {
                            Trans_Buffer[j] = 0x87;
                        }
                        else if (j == 1)
                        {
                            Trans_Buffer[j] = 0x86;
                        }
                        else if (j == 2)
                        {
                            Trans_Buffer[j] = 0x01;
                        }
                        else if (j == 3)
                        {
                            Trans_Buffer[j] = 0x00;
                        }
                        else
                        {
                            Trans_Buffer[j] = Trans_No_B[j - 4];
                        }
                    }

                    Success = Usb_Mine.Trans(512, Trans_Buffer);

                    if (!Success)
                    {
                        Usb_Mine.Reset();
                        Usb_Mine.ReConnect();
                    }
                    else
                    {
                        break;
                    }

                }

                Thread.Sleep(2);

                for (i = 0; i < 4;i++ )
                {
                    switch (i)
                    {
                        case 0:
                            Success = Usb_Mine.Collect(512, Collect_Buffer1);
                            break;
                        case 1:
                            Success = Usb_Mine.Collect(512, Collect_Buffer2);
                            break;
                        case 2:
                            Success = Usb_Mine.Collect(512, Collect_Buffer3);
                            break;
                        case 3:
                            Success = Usb_Mine.Collect(512, Collect_Buffer4);
                            break;
                    }
                    if(!Success)
                    {
                        Success = false;
                        break;
                    }
                    Success = true;
                }

                if (!Success)
                {
                    i --;
                    Usb_Mine.Reset();
                    Usb_Mine.ReConnect();
                }
                else
                {
                    Image_Matrix.Write(Collect_Buffer1);
                    Image_Matrix.Write(Collect_Buffer2);
                    Image_Matrix.Write(Collect_Buffer3);
                    Image_Matrix.Write(Collect_Buffer4);
                    Image_Matrix.Flush();
                    Trans_No ++;
                    Trans_No_B = BitConverter.GetBytes(Trans_No);
                }

                this.Dispatcher.BeginInvoke(Re_B, Trans_No * 100 / 1000);
                this.Dispatcher.BeginInvoke(Re_T, "世界线回调中......\n           " + Convert.ToString(Trans_No * 100 / 1000 * 100.0 / 1000) + "%");
            }

            int TransTime_E = System.Environment.TickCount;
            Image_Matrix_add.Close();
            this.Dispatcher.BeginInvoke(Re_T, "世界线回复速率\n              " + Convert.ToString(1024000 * 1000.0 / (TransTime_E - TransTime_S) / 1048576) + "MB/s");
            Collect.Abort();

            
        }

        void Onclick_Check(object sender, EventArgs e)
        {
            Usb_Mine.ReConnect();
            if (Usb_Mine.ReConnect())
            {
                t_statuses.Text = "→ 嗯，可以了哦～";
            }
            else
            {
                t_statuses.Text = "→ 忘记连接了，笨蛋！";
            }
        }

        public void Win()
        {
            Application app = new Application();

            FontFamily MyFontStyle = new FontFamily("华康少女文字 - kelvin");
            ImageBrush WinBackImage = new ImageBrush();
            WinBackImage.ImageSource = new BitmapImage(new Uri("pack://siteoforigin:,,,/Background.jpg", UriKind.RelativeOrAbsolute));


            MyWin.Title = "USB_PC";
            MyWin.Width = 640;
            MyWin.Height = 450;
            MyWin.WindowStyle = WindowStyle.SingleBorderWindow;
            MyWin.AllowsTransparency = false;
            MyWin.Background = WinBackImage;


            b_ok.Width = 80;
            b_ok.Height = 40;
            b_ok.Content = "传送";
            b_ok.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            b_ok.BorderThickness = new Thickness(0, 0, 0, 0);
            b_ok.FontFamily = MyFontStyle;
            b_ok.FontSize = 30;
            b_ok.Foreground = new SolidColorBrush(Color.FromArgb(200, 150, 100, 200));
            b_ok.Click += new RoutedEventHandler(Onclick_Trans);

            b_collect.Width = 80;
            b_collect.Height = 40;
            b_collect.Content = "采集";
            b_collect.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            b_collect.BorderThickness = new Thickness(0, 0, 0, 0);
            b_collect.FontFamily = MyFontStyle;
            b_collect.FontSize = 30;
            b_collect.Foreground = new SolidColorBrush(Color.FromArgb(200, 150, 100, 200));
            b_collect.Click += new RoutedEventHandler(Onclick_Collect);

            b_quit.Width = 80;
            b_quit.Height = 40;
            b_quit.Content = "退出";
            b_quit.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            b_quit.BorderThickness = new Thickness(0, 0, 0, 0);
            b_quit.FontFamily = MyFontStyle;
            b_quit.FontSize = 30;
            b_quit.Foreground = new SolidColorBrush(Color.FromArgb(200, 255, 0, 0));
            b_quit.Click += new RoutedEventHandler(Onclick_Quit);

            usb_check.Width = 60;
            usb_check.Height = 30;
            usb_check.Content = "连接";
            usb_check.BorderThickness = new Thickness(0, 0, 0, 0);
            usb_check.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            usb_check.FontFamily = MyFontStyle;
            usb_check.FontSize = 20;
            usb_check.Foreground = new SolidColorBrush(Color.FromArgb(200, 255, 0, 200));
            usb_check.Click += new RoutedEventHandler(Onclick_Check);

            usb_down.Width = 60;
            usb_down.Height = 30;
            usb_down.Content = "固件";
            usb_down.BorderThickness = new Thickness(0, 0, 0, 0);
            usb_down.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            usb_down.FontFamily = MyFontStyle;
            usb_down.FontSize = 20;
            usb_down.Foreground = new SolidColorBrush(Color.FromArgb(200, 255, 0, 200));
            usb_down.Click += new RoutedEventHandler(Onclick_Download);

            t_tital.Text = "3D_Displayer";
            t_tital.FontFamily = MyFontStyle;
            t_tital.FontSize = 35;
            t_tital.BorderThickness = new Thickness(0, 0, 0, 0);
            t_tital.Background = new SolidColorBrush(Color.FromArgb(0, 255, 255, 255));
            t_tital.Foreground = new SolidColorBrush(Color.FromArgb(200,50, 200, 200));

            t_statuses.FontFamily = MyFontStyle;
            t_statuses.FontSize = 20;
            t_statuses.BorderThickness = new Thickness(0, 0, 0, 0);
            t_statuses.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
            t_statuses.Foreground = new SolidColorBrush(Color.FromArgb(255, 255, 255, 100));

            trans_t.FontFamily = MyFontStyle;
            trans_t.FontSize = 22;
            trans_t.BorderThickness = new Thickness(0, 0, 0, 0);
            trans_t.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
            trans_t.Foreground = new SolidColorBrush(Color.FromArgb(200, 255, 100, 100));

            trans_bar.Width = 300;
            trans_bar.Height = 20;
            trans_bar.Background = new SolidColorBrush(Color.FromArgb(100, 255, 255, 255));
            trans_bar.BorderThickness = new Thickness(0, 0, 0, 0);
            trans_bar.Opacity = 150;
            trans_bar.Foreground = new SolidColorBrush(Color.FromArgb(100, 0, 150, 255));

            MyCanvas.Children.Add(b_ok);
            MyCanvas.Children.Add(b_quit);
            MyCanvas.Children.Add(usb_down);
            MyCanvas.Children.Add(b_collect);
            MyCanvas.Children.Add(usb_check);
            MyCanvas.Children.Add(t_tital);
            MyCanvas.Children.Add(t_statuses);
            MyCanvas.Children.Add(trans_bar);
            MyCanvas.Children.Add(trans_t);


            Canvas.SetLeft(b_ok, 0);
            Canvas.SetTop(b_ok, 320);
            Canvas.SetLeft(b_collect, 0);
            Canvas.SetTop(b_collect, 270);
            Canvas.SetLeft(b_quit, 0);
            Canvas.SetTop(b_quit, 370);
            Canvas.SetLeft(usb_check, 0);
            Canvas.SetTop(usb_check, 210);
            Canvas.SetLeft(usb_down, 0);
            Canvas.SetTop(usb_down, 170);
            Canvas.SetLeft(t_tital, 10);
            Canvas.SetTop(t_tital, 10);
            Canvas.SetLeft(t_statuses, 65);
            Canvas.SetTop(t_statuses, 215);
            Canvas.SetLeft(trans_bar, 5);
            Canvas.SetTop(trans_bar, 60);
            Canvas.SetLeft(trans_t, 30);
            Canvas.SetTop(trans_t, 90);

            MyWin.Content = MyCanvas;

            app.Run(MyWin);

        }

    }

    class Start
    {
        [STAThread]
        static void Main()
        {
            Winx MyWinx = new Winx();
            MyWinx.Win();
        }
    }

}