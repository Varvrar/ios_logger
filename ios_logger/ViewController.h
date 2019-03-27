#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv2/videoio/cap_ios.h>

using namespace cv;

@interface ViewController : UIViewController <CLLocationManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    __weak IBOutlet UIImageView *imageView;
    __weak IBOutlet UIButton *button;
    
    AVCaptureSession *session;
    AVCaptureDevice *device;
    AVCaptureDeviceInput *input;
    AVCaptureVideoDataOutput *output;
    dispatch_queue_t queue;
    
    CALayer *viewLayer;
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
    
    CMMotionManager *motionManager;
    CLLocationManager *locationManager;
        
    CMGyroData *gyroData;
    CMAccelerometerData *accelData;
    CLLocation *locationData;
    
    bool isRecording;
    bool isStarted;
    
    NSString *theDate;
    NSDateFormatter *dateFormat;
    
    double FPS;
    double imuFreq;
    
    NSMutableString  *logStringAccel;
    NSMutableString  *logStringGyro;
    NSMutableString  *logStringGps;
    NSMutableString  *logStringFrameStamps;
    
    VideoWriter videoFrames;
    unsigned int frameNum;
    
    float lensPosition;
    
    NSTimeInterval bootTime;
}

- (IBAction)toggleButton:(id)sender;

@end
