# ios_logger
Application for imu, camera and gps logging

This simple application was made for logging accelerometer, gyroscope, images and gps on Apple devices (iPad/iPhone).

## Build and run:
1. Open ios_logger.xcodeproj in XCode
2. In project properties -> General set your team signing and make sure that signing certificate was successfully created
3. Download [OpenCV framework](https://sourceforge.net/projects/opencvlibrary/files/) and put it in project directory. 
  Or in project properties -> Build Settings -> Framework Search Paths add path to folder with OpenCV framework. 
  I used 3.x version of OpenCV.
4. Connect your device, select it (Product -> Destination) and run application (Product -> Run)

## Collect datasets:
To start collecting dataset push "START" button on the device screen. When you want to stop collecting push "STOP" :-)
Each dataset will be saved in separate folder on device .

## Get saved datasets:
After you have collected datasets connect your device to PC and run iTunes. In iTunes go to device-> File Sharing -> ios-logger, in right table check folders with dataset you needed and save it on your PC.

## Dataset format:
* Accel.txt: time(s(from 1970)),ax(g),ay(g),az(g)
* Gyro.txt: time(s),gx(rad/s),gy(rad/s),gz(rad/s)
* GPS.txt: time(s),latitude(deg),longitude(deg)
* Frames.txt: time(s),frameNumber
* Frames.m4v: frames compressed in video 

To syncronize accelerometer and gyroscope data you can use python script sync-data.py:
```
python D:/Datasets/sync-data.py D:/Datasets/2019-02-08T14-26-03
```

To get frames from video you can use ffmpeg or some video editor. For example: 
```
ffmpeg -i Frames.m4v Frames/Frame%05d.png -hide_banner
```
or you can try to use VideoToPictures.cpp:
```
compile VideoToPictures.cpp and
VideoToPictures.exe D:/Datasets/2019-02-08T14-26-03/Frames.m4v
```
