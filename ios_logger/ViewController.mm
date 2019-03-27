#import "ViewController.h"

@interface ViewController ()
{
    
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //--------
    FPS = 30;
    imuFreq = 100;
    
    lensPosition = 1.0;
    
    dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH-mm-ss"]; //"dd-MM-yyyy-HH-mm-SS"
    
    gyroData = nil;
    accelData = nil;
    locationData = nil;
    
    logStringAccel = [NSMutableString stringWithString: @""];
    logStringGyro = [NSMutableString stringWithString: @""];
    logStringGps = [NSMutableString stringWithString: @""];
    logStringFrameStamps = [NSMutableString stringWithString: @""];
    
    isRecording = false;
    isStarted = false;
    
    bootTime =  [[NSDate date] timeIntervalSince1970] - [[NSProcessInfo processInfo] systemUptime];
    
    //--------
    motionManager = [[CMMotionManager alloc] init];
    motionManager.gyroUpdateInterval = 1./imuFreq;
    motionManager.accelerometerUpdateInterval = 1./imuFreq;
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.distanceFilter = kCLDistanceFilterNone;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [locationManager requestWhenInUseAuthorization];
    }
    
    [locationManager startUpdatingLocation];
    
    //******************************
    session = [AVCaptureSession new];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    [session addInput:input];
    
    output = [AVCaptureVideoDataOutput new];

    NSDictionary *newSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    output.videoSettings = newSettings;
    
    [session addOutput:output];

    
    queue = dispatch_queue_create("MyQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    [device lockForConfiguration:nil];
    double epsilon = 0.00000001;
    device.activeVideoMinFrameDuration = CMTimeMake(1, FPS - epsilon);
    device.activeVideoMaxFrameDuration = CMTimeMake(1, FPS + epsilon);
    //device.activeFormat.videoSupportedFrameRateRanges;
    [device setFocusModeLockedWithLensPosition:lensPosition completionHandler:nil];
    [device unlockForConfiguration];
    
    /*NSString *mediaType = AVMediaTypeVideo;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (!granted){
            //Not granted access to mediaType
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"AVCam!"
                                            message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
            });
        }
    }];*/
    
    CALayer *viewLayer = imageView.layer;
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    [viewLayer insertSublayer:captureVideoPreviewLayer atIndex:0];
    captureVideoPreviewLayer.frame = imageView.frame;
    
    [session startRunning];
    //******************************
    //-------
    NSOperationQueue *gyroQueue = [[NSOperationQueue alloc] init];
    [motionManager startGyroUpdatesToQueue:gyroQueue
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
    
    NSOperationQueue *accelQueue = [[NSOperationQueue alloc] init];
    [motionManager startAccelerometerUpdatesToQueue:accelQueue
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
                                       acceldata.acceleration.x,
                                       acceldata.acceleration.y,
                                       acceldata.acceleration.z]];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    locationData = [locations lastObject];
    
    if (isRecording && locationData != nil)
    {
        double currLatitude = locationData.coordinate.latitude;
        double currLongitude = locationData.coordinate.longitude;
        
        double msDate = [locationData.timestamp timeIntervalSince1970];
        [logStringGps appendString: [NSString stringWithFormat:@"%f,%f,%f\r\n",
                          msDate,
                          currLatitude,
                          currLongitude]];
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if(isStarted || isRecording)
    {
        //double msDate = [[NSDate date] timeIntervalSince1970];
        CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        double msDate = bootTime + CMTimeGetSeconds(frameTime);
        
        CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CVPixelBufferLockBaseAddress(buffer, 0);
        
        void *address =  CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
        int bufferWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,0);
        int bufferHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 0);
        int bytePerRow = (int)CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
        OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);
        
        cv::Mat mat = cv::Mat(bufferHeight, bufferWidth, CV_8UC4, address, bytePerRow);
        
        [self processImage:mat Timestamp:msDate];
        
        CVPixelBufferUnlockBaseAddress(buffer, 0);
    }
}

- (void)processImage:(Mat&)image Timestamp:(double)msDate
{
    if(isStarted)
    {
        if (locationData != nil)
        {
            double currLatitude = locationData.coordinate.latitude;
            double currLongitude = locationData.coordinate.longitude;
            
            [logStringGps appendString: [NSString stringWithFormat:@"%f,%f,%f\r\n",
                                         msDate,
                                         currLatitude,
                                         currLongitude]];
        }
        
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
        
        [logStringFrameStamps appendString: [NSString stringWithFormat:@"%f,%u\r\n",
                                             msDate,
                                             frameNum]];
        videoFrames.write(image);
    }
}

- (IBAction)toggleButton:(id)sender
{
    if (!isRecording && !isStarted)
    {
        isStarted = YES;
        
        [logStringAccel setString:@""];
        [logStringGyro setString:@""];
        [logStringGps setString:@""];
        [logStringFrameStamps setString:@""];
        
        frameNum = 0;
        
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
        
        [self writeStringToFile:logStringGyro FileName:@"Gyro"];
        [self writeStringToFile:logStringAccel FileName:@"Accel"];
        [self writeStringToFile:logStringGps FileName:@"GPS"];
        [self writeStringToFile:logStringFrameStamps FileName:@"Frames"];
        
        videoFrames.release();

        [sender setTitle:@"START" forState:UIControlStateNormal];
    }
}

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

@end
