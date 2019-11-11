//
//  ViewController.m
//  cig_logger
//
//  Created by Mac on 27/08/2018.
//  Copyright © 2018 Mac. All rights reserved.
//
//--------------------------------------------

#import "ViewController.h"

@interface ViewController ()
{
    
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib
    //std::cout << "*** opencv version " << CV_VERSION << std::endl;
    //--------
    FPS = 30;
    imuFreq = 100;
    
    lensPosition = afSlider.value;
    afLabel.text = [NSString stringWithFormat:@"%5.3f",afSlider.value];
    
    dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH-mm-ss"]; //"dd-MM-yyyy-HH-mm-SS"
    
    locationData = nil;
    headingData = nil;
    
    arSession = nil;
    arConfiguration = nil;
    
    logStringAccel = [NSMutableString stringWithString: @""];
    logStringGyro = [NSMutableString stringWithString: @""];
    logStringMotion = [NSMutableString stringWithString: @""];
    logStringMotARH = [NSMutableString stringWithString: @""];
    logStringMotMagnFull = [NSMutableString stringWithString: @""];
    logStringMagnet = [NSMutableString stringWithString: @""];
    logStringGps = [NSMutableString stringWithString: @""];
    logStringHeading = [NSMutableString stringWithString: @""];
    logStringFrameStamps = [NSMutableString stringWithString: @""];
    logStringArPose = [NSMutableString stringWithString: @""];
    
    fr_height = MAX(self.view.frame.size.width, self.view.frame.size.height);
    fr_width = MIN(self.view.frame.size.width, self.view.frame.size.height);
    
    isRecording = false;
    isStarted = false;
    
    bootTime =  [[NSDate date] timeIntervalSince1970] - [[NSProcessInfo processInfo] systemUptime];
    
    reduseFpsInNTimes = 1;
    
    prevFrTs = -1.0;
    
    //--------
    motionManager = [[CMMotionManager alloc] init];
    motionManager.gyroUpdateInterval = 1./imuFreq;
    motionManager.accelerometerUpdateInterval = 1./imuFreq;
    motionManager.deviceMotionUpdateInterval = 1./imuFreq;
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    locationManager.headingOrientation = CLDeviceOrientationLandscapeLeft; //Left - "with the device held upright and the home button on the right side"
    locationManager.headingFilter = kCLHeadingFilterNone;
    
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [locationManager requestWhenInUseAuthorization];
    }

    accelgyroQueue = [[NSOperationQueue alloc] init];
    motionQueue = [[NSOperationQueue alloc] init];
    magnetQueue = [[NSOperationQueue alloc] init];
    
    [self accgyroSwChanged:accgyroSwitch];
    [self gpsheadSwChanged:gpsheadSwitch];
    [self motionSwChanged:motionSwitch];
    [self magnetSwChanged:magnetSwitch];
    //******************************
    session = [AVCaptureSession new];

    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input){
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController * alert = [UIAlertController
                                            alertControllerWithTitle:@"Error"
                                            message:[NSString stringWithFormat:@"AVCaptureDeviceInput: %@", error]
                                            preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
            [alert addAction:okButton];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }
    
    [session addInput:input];
    
    output = [AVCaptureVideoDataOutput new];

    NSDictionary *newSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    output.videoSettings = newSettings;
    
    [session addOutput:output];

    sbfQueue = dispatch_queue_create("MyQueue", NULL);
    [output setSampleBufferDelegate:self queue:sbfQueue];
    
    [device lockForConfiguration:nil];

    device.activeVideoMinFrameDuration = CMTimeMake(1, FPS);
    device.activeVideoMaxFrameDuration = CMTimeMake(1, FPS);

    [device setFocusModeLockedWithLensPosition:lensPosition completionHandler:nil];
    [device unlockForConfiguration];
    
    NSString *mediaType = AVMediaTypeVideo;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (!granted){
            //Not granted access to mediaType
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:@"Error"
                                             message:@"AVCapture doesn't have permission to use camera"
                                             preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
                [alert addAction:okButton];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    }];
    
    NSArray<__kindof AVCaptureOutput *> *_outputs = session.outputs;
    for (int i = 0; i < [_outputs count]; ++i) {
            NSArray<AVCaptureConnection *> *_connections = _outputs[i].connections;
            for (int j = 0; j < [_connections count]; ++j) {
                if(_connections[j].isCameraIntrinsicMatrixDeliverySupported)
                    _connections[j].cameraIntrinsicMatrixDeliveryEnabled = true;
        }
    }
    
    //******************************
    if(ARWorldTrackingConfiguration.isSupported){
        arConfiguration = [[ARWorldTrackingConfiguration alloc] init];
        arConfiguration.worldAlignment = ARWorldAlignmentGravity;//ARWorldAlignmentGravityAndHeading;
    }
    else{
        [segmentedControl removeSegmentAtIndex:3 animated:NO];
    }
    //-------

    [self segmentedControlValueChanged:segmentedControl];

}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    // Pause the view's AR session.
    [arSession pause];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

-(void)outputRotationData:(CMGyroData *)gyrodata
{
    //gyroData = gyrodata;
    
    if (isRecording && gyrodata != nil)
    {
        double msDate = bootTime + gyrodata.timestamp;
        [logStringGyro appendString: [NSString stringWithFormat:@"%f,%f,%f,%f\r\n",
                                      msDate,
                                      gyrodata.rotationRate.x,
                                      gyrodata.rotationRate.y,
                                      gyrodata.rotationRate.z]];
    }
}

-(void)outputAccelertionData:(CMAccelerometerData *)acceldata
{
    //accelData = acceldata;
    
    if (isRecording && acceldata != nil)
    {
        double msDate = bootTime + acceldata.timestamp;
        [logStringAccel appendString: [NSString stringWithFormat:@"%f,%f,%f,%f\r\n",
                                       msDate,
                                       acceldata.acceleration.x, //G-units
                                       acceldata.acceleration.y,
                                       acceldata.acceleration.z]];
    }
}

-(void)outputMagnetometerData:(CMMagnetometerData *)magnetdata
{
    if (isRecording && magnetdata != nil)
    {
        double msDate = bootTime + magnetdata.timestamp;
        [logStringMagnet appendString: [NSString stringWithFormat:@"%f,%f,%f,%f\r\n",
                                       msDate,
                                       magnetdata.magneticField.x, //microteslas
                                       magnetdata.magneticField.y,
                                       magnetdata.magneticField.z]];
    }
}

-(void)outputDeviceMotionData:(CMDeviceMotion *)devmotdata
{
    if (isRecording && devmotdata != nil)
    {
        double msDate = bootTime + devmotdata.timestamp;
        
        CMQuaternion quat = devmotdata.attitude.quaternion;
        [logStringMotion appendString: [NSString stringWithFormat:@"%f,%f,%f,%f,%f\r\n",
                                       msDate,
                                        quat.w,
                                        quat.x,
                                        quat.y,
                                        quat.z]];
        
        CMRotationRate rotr = devmotdata.rotationRate;
        CMAcceleration grav = devmotdata.gravity;
        CMAcceleration usracc = devmotdata.userAcceleration;
        [logStringMotARH appendString: [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\r\n",
                                       msDate,
                                        rotr.x,
                                        rotr.y,
                                        rotr.z,
                                        grav.x,
                                        grav.y,
                                        grav.z,
                                        usracc.x,
                                        usracc.y,
                                        usracc.z,
                                        devmotdata.heading]];
        
        CMCalibratedMagneticField calmagnfield = devmotdata.magneticField;
        [logStringMotMagnFull appendString: [NSString stringWithFormat:@"%f,%f,%f,%f,%d\r\n",
                                       msDate,
                                        calmagnfield.field.x,
                                        calmagnfield.field.y,
                                        calmagnfield.field.z,
                                        calmagnfield.accuracy]];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    locationData = [locations lastObject];
    
    [self updateLocation:locationData];
}

-(void)updateLocation:(CLLocation *)location
{
    if (isRecording && location != nil)
    {
        double currLatitude = location.coordinate.latitude;
        double currLongitude = location.coordinate.longitude;
        double currHorAccur = location.horizontalAccuracy;
        double currAltitude = location.altitude;
        double currVertAccur = location.verticalAccuracy;
        long currFloor = location.floor.level;
        double currCource = location.course;
        double currSpeed = location.speed;
        
        double msDate = [location.timestamp timeIntervalSince1970];
        [logStringGps appendString: [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%ld,%f,%f\r\n",
                          msDate,
                          currLatitude,
                          currLongitude,
                          currHorAccur,
                          currAltitude,
                          currVertAccur,
                          currFloor,
                          currCource,
                          currSpeed]];
    }
}

- (void) locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    headingData = newHeading;
    
    [self updateHeading:headingData];
}

-(void)updateHeading:(CLHeading *)heading
{
    if (isRecording && heading != nil)
    {
        double currTrueHeading = heading.trueHeading;
        double currMagneticHeading = heading.magneticHeading;
        double currHeadingAccuracy = heading.headingAccuracy;
        
        double msDate = [heading.timestamp timeIntervalSince1970];
        [logStringHeading appendString: [NSString stringWithFormat:@"%f,%f,%f,%f\r\n",
                          msDate,
                          currTrueHeading,
                          currMagneticHeading,
                          currHeadingAccuracy]];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Error"
                                 message:[NSString stringWithFormat:@"Location update: %@", error]
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
}

-(cv::Mat)matFromPixelBuffer:(CVPixelBufferRef) buffer{
    cv::Mat mat;
    //Lock the base Address so it doesn't get changed!
    CVPixelBufferLockBaseAddress(buffer, 0);
    //Get the data from the first plane (Y)
    void *address =  CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    int bufferWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,0);
    int bufferHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 0);
    int bytePerRow = (int)CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
    //Get the pixel format
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);
    
    cv::Mat converted;
    //NOTE: CV_8UC3 means unsigned (0-255) 8 bits per pixel, with 3 channels!
    //Check to see if this is the correct pixel format
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        //We have an ARKIT buffer
        //Get the yPlane (Luma values)
        cv::Mat yPlane = cv::Mat(bufferHeight, bufferWidth, CV_8UC1, address);
        
        //Get cbcrPlane (Chroma values)
        int cbcrWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,1);
        int cbcrHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 1);
        void *cbcrAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1);
        //Since the CbCr Values are alternating we have 2 channels: Cb and Cr. Thus we need to use CV_8UC2 here.
        cv::Mat cbcrPlane = cv::Mat(cbcrHeight, cbcrWidth, CV_8UC2, cbcrAddress);
        
        //Split them apart so we can merge them with the luma values
        std::vector<cv::Mat> cbcrPlanes;
        cv::split(cbcrPlane, cbcrPlanes);
        
        cv::Mat cbPlane;
        cv::Mat crPlane;
        
        //Since we have a 4:2:0 format, cb and cr values are only present for each 2x2 luma pixels. Thus we need to enlargen them (by a factor of 2).
        cv::resize(cbcrPlanes[0], cbPlane, yPlane.size(), 0, 0, cv::INTER_NEAREST);
        cv::resize(cbcrPlanes[1], crPlane, yPlane.size(), 0, 0, cv::INTER_NEAREST);
        
        cv::Mat ycbcr;
        std::vector<cv::Mat> allPlanes = {yPlane, cbPlane, crPlane};
        cv::merge(allPlanes, ycbcr);
        
        //ycbcr now contains all three planes. We need to convert it from YCbCr to RGB so OpenCV can work with it
        
        cv::cvtColor(ycbcr, converted, cv::COLOR_YCrCb2RGB);
    } else {
        //Probably RGB so just use that.
        converted = cv::Mat(bufferHeight, bufferWidth, CV_8UC3, address, bytePerRow).clone();
    }
    
    //Since we clone the cv::Mat no need to keep the Buffer Locked while we work on it.
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return converted;
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    double msDate = bootTime + frame.timestamp;
    
    if(prevFrTs >= 0)
        if(reduseFpsInNTimes * (msDate - prevFrTs) < (1.0/FPS)/1.5)
            reduseFpsInNTimes++;
    prevFrTs = msDate;
    
    if(ireduceFps == 0)
    {
        img = [self matFromPixelBuffer:frame.capturedImage];
        matrix_float3x3 camMat = frame.camera.intrinsics;
        [self processImage:img Timestamp:msDate CameraMatrix:&camMat];
    }
    if(ireduceFps == (reduseFpsInNTimes-1))
        ireduceFps = 0;
    else
        ++ireduceFps;
    
    simd_float4x4 trans = frame.camera.transform;
    simd_quatf quat = /*simd_normalize*/(simd_quaternion(trans));
    [logStringArPose appendString: [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f,%f\r\n",
                                    msDate,
                                    trans.columns[3][0], trans.columns[3][1], trans.columns[3][2],
                                    quat.vector[3], quat.vector[0], quat.vector[1], quat.vector[2]
                                    ]];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    //if(isStarted || isRecording)
    {
        matrix_float3x3 *camMatrix = nullptr;
        
        if(isRecording || isStarted)
        {
            if(connection.isCameraIntrinsicMatrixDeliveryEnabled)
            {
                CFTypeRef cameraIntrinsicData = CMGetAttachment(sampleBuffer,
                                                                kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                                                nil);
                
                if(cameraIntrinsicData != nil)
                    if (CFGetTypeID(cameraIntrinsicData) == CFDataGetTypeID()) {
                        CFDataRef cfdr = (CFDataRef)(cameraIntrinsicData);
                        
                        camMatrix = (matrix_float3x3 *)(CFDataGetBytePtr(cfdr));
                    }
            }
        }
        
        //double msDate = [[NSDate date] timeIntervalSince1970];
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        double msDate = bootTime + CMTimeGetSeconds(frameTime);
        
        CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CVPixelBufferLockBaseAddress(buffer, 0);
        
        void *address =  CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
        int bufferWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,0);
        int bufferHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 0);
        int bytePerRow = (int)CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
        //OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);
        
        img = cv::Mat(bufferHeight, bufferWidth, CV_8UC4, address, bytePerRow);
        
        [self processImage:img Timestamp:msDate CameraMatrix:camMatrix];
        
        CVPixelBufferUnlockBaseAddress(buffer, 0);
    }
}

- (void)processImage:(Mat&)image Timestamp:(double)msDate CameraMatrix:(matrix_float3x3*)camMat
{
    //crop_resize(image, image, cv::Size(800,600));
    
    if(isStarted)
    {
        [self updateLocation:locationData];
        [self updateHeading:headingData];
        
        //------------
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        NSString *filePath = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%@/%@/Frames.m4v", documentsDirectory, theDate]];
        
        const char* filePathC = [filePath cStringUsingEncoding:NSMacOSRomanStringEncoding];
        const cv::String filePathS = (const cv::String)filePathC;
        
        videoFrames.open(filePathS, CV_FOURCC('X','V','I','D'), FPS, image.size());
        //------------
        
        isStarted = NO;
        isRecording = YES;
    }
    
    if(isRecording)
    {
        frameNum += 1;
        
        if(camMat != nullptr){
            [logStringFrameStamps appendString: [NSString stringWithFormat:@"%f,%u,%f,%f,%f,%f\r\n",
                                                 msDate,
                                                 frameNum,
                                                 camMat->columns[0][0],
                                                 camMat->columns[1][1],
                                                 camMat->columns[2][0],
                                                 camMat->columns[2][1]]];
        }
        else{
            [logStringFrameStamps appendString: [NSString stringWithFormat:@"%f,%u\r\n",
                                                 msDate,
                                                 frameNum]];
        }
        videoFrames.write(image);

        UIImage *img = [ViewController UIImageFromCVMat:image];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->imageView.image = img;
        });
    }
    else
    {
        UIImage *img = MatToUIImage(image);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->imageView.image = img;
        });
    }
}

- (void)_timerFired:(NSTimer *)timer {
    //NSLog(@"ping");
    iTimer += 1;
    NSString *timeStr = [NSString stringWithFormat:@"%.2d:%.2d",iTimer/60,iTimer%60];
    runTimeLabel.text = timeStr;
}

- (IBAction)toggleButton:(id)sender
{
    if (!isRecording && !isStarted)
    {
        isStarted = YES;
        
        if (!_timer) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:1.
                                                      target:self
                                                    selector:@selector(_timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
        }
        iTimer = 0;
        
        runTimeLabel.text = @"00:00";
        afButton.enabled = NO;
        if(!isAf){
            afSlider.enabled = NO;
            afLabel.enabled = NO;
        }
        segmentedControl.enabled = NO;
        accgyroSwitch.enabled = NO;
        gpsheadSwitch.enabled = NO;
        motionSwitch.enabled = NO;
        magnetSwitch.enabled = NO;
        
        [logStringAccel setString:@""];
        [logStringGyro setString:@""];
        [logStringMotion setString:@""];
        [logStringMotARH setString:@""];
        [logStringMotMagnFull setString:@""];
        [logStringMagnet setString:@""];
        [logStringGps setString:@""];
        [logStringHeading setString:@""];
        [logStringFrameStamps setString:@""];
        [logStringArPose setString:@""];
        
        frameNum = 0;
        ireduceFps = 0;
        
        NSDate *now = [[NSDate alloc] init];
        theDate = [dateFormat stringFromDate:now];
        
        [self createFolderInDocuments:theDate];
        
        [sender setTitle:@"STOP" forState:UIControlStateNormal];
    }
    //----------------------------------------------------------
    else
    if (!isStarted)
    {
        isRecording = NO;
        
        if ([_timer isValid]) {
            [_timer invalidate];
        }
        _timer = nil;
        afButton.enabled = YES;
        if(!isAf){
            afSlider.enabled = YES;
            afLabel.enabled = YES;
        }
        segmentedControl.enabled = YES;
        accgyroSwitch.enabled = YES;
        gpsheadSwitch.enabled = YES;
        motionSwitch.enabled = YES;
        magnetSwitch.enabled = YES;
        
        if(accgyroSwitch.isOn){
            [self writeStringToFile:logStringGyro FileName:@"Gyro"];
            [self writeStringToFile:logStringAccel FileName:@"Accel"];
        }
        if(motionSwitch.isOn){
            [self writeStringToFile:logStringMotion FileName:@"Motion"];
            [self writeStringToFile:logStringMotARH FileName:@"MotARH"];
            [self writeStringToFile:logStringMotMagnFull FileName:@"MotMagnFull"];
        }
        if(magnetSwitch.isOn){
            [self writeStringToFile:logStringMagnet FileName:@"Magnet"];
        }
        if(gpsheadSwitch.isOn){
            [self writeStringToFile:logStringGps FileName:@"GPS"];
            [self writeStringToFile:logStringHeading FileName:@"Head"];
        }
        [self writeStringToFile:logStringFrameStamps FileName:@"Frames"];
        if(segmentedControl.selectedSegmentIndex == 3)
            [self writeStringToFile:logStringArPose FileName:@"ARposes"];
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
        dispatch_async(queue, ^{
            self->videoFrames.release();
        });

        [sender setTitle:@"START" forState:UIControlStateNormal];
    }
}

- (IBAction)toggleAfButton:(id)sender {
    if(!isAf){
        if(segmentedControl.selectedSegmentIndex == 3)
        {
            arSession = [ARSession new];
            arSession.delegate = self;
            if (@available(iOS 11.3, *)) {
                arConfiguration.autoFocusEnabled = true;
            } else {
                // Fallback on earlier versions
            }
            [arSession runWithConfiguration:arConfiguration];
        }
        else
        {
            afSlider.enabled = NO;
            afLabel.hidden = YES;
            
            [device lockForConfiguration:nil];
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            [device unlockForConfiguration];
        }
        
        isAf = YES;
        [sender setTitle:@"AF:ON" forState:UIControlStateNormal];
    }
    else{
        if(segmentedControl.selectedSegmentIndex == 3)
        {
            arSession = [ARSession new];
            arSession.delegate = self;
            if (@available(iOS 11.3, *)) {
                arConfiguration.autoFocusEnabled = false;
            } else {
                // Fallback on earlier versions
            }
            [arSession runWithConfiguration:arConfiguration];
        }
        else
        {
            afSlider.enabled = YES;
            afLabel.hidden = NO;
            
            [device lockForConfiguration:nil];
            [device setFocusModeLockedWithLensPosition:lensPosition completionHandler:nil];
            [device unlockForConfiguration];
        }
        
        isAf = NO;
        [sender setTitle:@"AF:OFF" forState:UIControlStateNormal];
    }
}

- (IBAction)afSliderValueChanged:(id)sender {
    afLabel.text = [NSString stringWithFormat:@"%5.3f",afSlider.value];
}

- (IBAction)afSliderEndEditing:(id)sender {
    lensPosition = afSlider.value;
    [device lockForConfiguration:nil];
    [device setFocusModeLockedWithLensPosition:lensPosition completionHandler:nil];
    [device unlockForConfiguration];
}

- (IBAction)segmentedControlValueChanged:(UISegmentedControl *)sender {
    switch(sender.selectedSegmentIndex)
    {
        case 0:
            if(arSession != nil)
            {
                arSession = nil;
                afSlider.hidden = NO;
                afLabel.hidden = NO;
                if((device.focusMode == AVCaptureFocusModeLocked) && isAf){
                    isAf = !isAf;
                    [self toggleAfButton:afButton];
                }
            }
            if([session canSetSessionPreset:AVCaptureSessionPreset640x480])
                session.sessionPreset = AVCaptureSessionPreset640x480;
            if(![session isRunning])
            {
                [session startRunning];
            }
            break;
        case 1:
            if(arSession != nil)
            {
                arSession = nil;
                afSlider.hidden = NO;
                afLabel.hidden = NO;
                if((device.focusMode == AVCaptureFocusModeLocked) && isAf){
                    isAf = !isAf;
                    [self toggleAfButton:afButton];
                }
            }
            if([session canSetSessionPreset:AVCaptureSessionPreset1280x720])
                session.sessionPreset = AVCaptureSessionPreset1280x720;
            if(![session isRunning])
            {
                [session startRunning];
            }
            break;
        case 2:
            if(arSession != nil)
            {
                arSession = nil;
                afSlider.hidden = NO;
                afLabel.hidden = NO;
                if((device.focusMode == AVCaptureFocusModeLocked) && isAf){
                    isAf = !isAf;
                    [self toggleAfButton:afButton];
                }
            }
            if([session canSetSessionPreset:AVCaptureSessionPreset1920x1080])
                session.sessionPreset = AVCaptureSessionPreset1920x1080;
            if(![session isRunning])
            {
                [session startRunning];
            }
            break;
        case 3:
            afSlider.hidden = YES;
            afLabel.hidden = YES;
            if([session isRunning])
                    [session stopRunning];
            isAf = !isAf;
            [self toggleAfButton:afButton]; // arSession start
            break;
        default: sender.selectedSegmentIndex = UISegmentedControlNoSegment;
    }
}

//*************************************************************************

- (IBAction)accgyroSwChanged:(UISwitch *)sender {
    if ( sender.isOn ){
        [motionManager startGyroUpdatesToQueue:accelgyroQueue
                                   withHandler:^(CMGyroData *gyroData, NSError *error) {
                                       [self outputRotationData:gyroData];
                                       if(error){
                                           UIAlertController * alert = [UIAlertController
                                                                        alertControllerWithTitle:@"Error"
                                                                        message:[NSString stringWithFormat:@"Gyroscope update: %@", error]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                                           
                                           UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
                                           [alert addAction:okButton];
                                           [self presentViewController:alert animated:YES completion:nil];
                                       }
                                   }];
        
        [motionManager startAccelerometerUpdatesToQueue:accelgyroQueue
                                            withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                                [self outputAccelertionData:accelerometerData];
                                                if(error){
                                                    UIAlertController * alert = [UIAlertController
                                                                                 alertControllerWithTitle:@"Error"
                                                                                 message:[NSString stringWithFormat:@"Accelerometer update: %@", error]
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                                                    
                                                    UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
                                                    [alert addAction:okButton];
                                                    [self presentViewController:alert animated:YES completion:nil];
                                                }
                                            }];
    }
    else{
        [motionManager stopAccelerometerUpdates];
        [motionManager stopGyroUpdates];
    }
}

- (IBAction)gpsheadSwChanged:(UISwitch *)sender {
    if ( sender.isOn ){
         [locationManager startUpdatingLocation];
         
         if([CLLocationManager headingAvailable])
             [locationManager startUpdatingHeading];
    }
    else{
        [locationManager stopUpdatingLocation];
        
        if([CLLocationManager headingAvailable])
            [locationManager stopUpdatingHeading];
    }
}

- (IBAction)motionSwChanged:(UISwitch *)sender {
    if ( sender.isOn ){
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXTrueNorthZVertical toQueue:motionQueue
                                    withHandler:^(CMDeviceMotion *devmotData, NSError *error) {
                                        [self outputDeviceMotionData:devmotData];
                                        if(error){
                                            UIAlertController * alert = [UIAlertController
                                                                         alertControllerWithTitle:@"Error"
                                                                         message:[NSString stringWithFormat:@"DeviceMotion update: %@", error]
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                            
                                            UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
                                            [alert addAction:okButton];
                                            [self presentViewController:alert animated:YES completion:nil];
                                        }
        }];
    }
    else{
        [motionManager stopDeviceMotionUpdates];
    }
}

- (IBAction)magnetSwChanged:(UISwitch *)sender {
    if ( sender.isOn ){
        [motionManager startMagnetometerUpdatesToQueue:magnetQueue
                                            withHandler:^(CMMagnetometerData *magnetData, NSError *error) {
                                                [self outputMagnetometerData:magnetData];
                                                if(error){
                                                    UIAlertController * alert = [UIAlertController
                                                                                 alertControllerWithTitle:@"Error"
                                                                                 message:[NSString stringWithFormat:@"Magnetometer update: %@", error]
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
                                                    
                                                    UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
                                                    [alert addAction:okButton];
                                                    [self presentViewController:alert animated:YES completion:nil];
                                                }
                                            }];
    }
    else{
        [motionManager stopMagnetometerUpdates];
    }
}

//*************************************************************************

-(BOOL) writeStringToFile:(NSMutableString *)aString FileName:(NSString *)nameString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *filePath= [[NSString alloc] initWithString:[NSString stringWithFormat:@"%@/%@/%@.txt",documentsDirectory, theDate, nameString]];
    
    BOOL success = [[aString dataUsingEncoding:NSUTF8StringEncoding] writeToFile:filePath atomically:YES];
    
    return success;
}

-(BOOL) createFolderInDocuments:(NSString *)folderName
{
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:folderName];
    
    BOOL success = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
        success = [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    if(error){
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Error"
                                     message:[NSString stringWithFormat:@"Create folder: %@", error]
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){}];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    return success;
}

+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.step.p[0]*cvMat.rows];
    
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Little | (
                                                   cvMat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst
                                                   );
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(
                                        cvMat.cols,                 //width
                                        cvMat.rows,                 //height
                                        8,                          //bits per component
                                        8 * cvMat.elemSize(),       //bits per pixel
                                        cvMat.step[0],              //bytesPerRow
                                        colorSpace,                 //colorspace
                                        bitmapInfo,                 // bitmap info
                                        provider,                   //CGDataProviderRef
                                        NULL,                       //decode
                                        false,                      //should interpolate
                                        kCGRenderingIntentDefault   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

+ (cv::Mat)cvMatWithImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
    
    // check whether the UIImage is greyscale already
    if (numberOfComponents == 1){
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,             // Pointer to backing data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    bitmapInfo);              // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

@end
