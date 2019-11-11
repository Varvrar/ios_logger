# ios_logger
Application for logging camera images, accelerometer and gyroscope data,  gps and heading data, motion data and magnet data. 

This application was made for logging camera images and sensor data on Apple devices (iPad/iPhone).

## Build and run:
1. Open ios_logger.xcodeproj in XCode
2. In project properties -> General set your team signing and make sure that signing certificate was successfully created
3. Download [OpenCV framework](https://sourceforge.net/projects/opencvlibrary/files/) and put it in project directory. 
  Or in project properties -> Build Settings -> Framework Search Paths add path to folder with OpenCV framework. 
  I used 3.x version of OpenCV.
4. Connect your device (you may have to wait for the debugger to be set up), select it (Product -> Destination) and run application (Product -> Run)

## Collect datasets:
To start collecting dataset:
* set required image resolution in upper-left corner
* **if you check ARKit segment - app will use ARKit to get camera images (with ARKit native resolution - depends on device) + app will _logging ARKit poses of the device_ (with origin in place where "START" button was pressed)**
* set switches with required sensors to be logged
* _you can set AutoFocus on/off with "AF" button_
* _with off AutoFocus you can set camera focal lenth by slider in bottom-right corned_
* press "START" button
* when you want to stop collecting dataset press "STOP" :-)

Each dataset will be saved in separate folder on the device .

## Get saved datasets:
After you have collected datasets connect your device to PC and run iTunes. In iTunes go to device-> File Sharing -> ios-logger, in right table check folders with datasets you needed and save it on your PC. 
In last versions of MacOS you should use finder to acess the device and get File Sharing.

## Dataset format:
* Accel.txt: time(s(from 1970)),ax(g-units),ay(g-units),az(g-units)
* Gyro.txt: time(s),gx(rad/s),gy(rad/s),gz(rad/s)
* GPS.txt: time(s),latitude(deg),longitude(deg),horizontalAccuracy(m),altitude(m),verticalAccuracy(m),floorLevel,course(dgr),speed(m/s)
* Head.txt: time(s),trueHeading(dgr),magneticHeading(dgr),headingAccuracy(dgr)
* Motion.txt: time(s),attitude.quaternion.w,attitude.quaternion.x,attitude.quaternion.y,attitude.quaternion.z
* MotARH.txt: time(s),rotationRate.x(rad/s),rotationRate.y(rad/s),rotationRate.z(rad/s),gravity.x(g-units),gravity.y(g-units),gravity.z(g-units),userAccel.x(g-units),userAccel.y(g-units),userAccel.z(g-units),motionHeading(dgr)
* MotMagnFull.txt: time(s),calibratedMagnField.x(microteslas),calibratedMagnField.y(microteslas),calibratedMagnField.z(microteslas),magnFieldAccuracy
* Magnet.txt: time(s),magneticField.x(microteslas),magneticField.y(microteslas),magneticField.z(microteslas)
* ARposes.txt: time(s),ARKit.translation.x(m),ARKit.translation.y(m),ARKit.translation.z(m),ARKit.quaternion.w,ARKit.quaternion.x,ARKit.quaternion.y,ARKit.quaternion.z
* Frames.txt: time(s),frameNumber,_focalLenghtX,focalLenghtY,principalPointX,principalPointY_
* Frames.m4v: frames compressed in video 

## Other:
_To syncronize accelerometer and gyroscope data_ you can use python script sync-data.py:
```
python path_to_folder_with_sync-data/sync-data.py path_to_datasets_folder/dataset_folder
```

_To get frames from video you can use ffmpeg or some video editor._
For example: 
```
ffmpeg -i Frames.m4v Frames/Frame%05d.png -hide_banner
```
or you can try to use VideoToPictures.cpp:
```
compile VideoToPictures.cpp and
VideoToPictures path_to_datasets_folder/dataset_folder/Frames.m4v
```
