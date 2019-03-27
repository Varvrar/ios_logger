#include <iostream>
#include "opencv2/opencv.hpp"

#ifdef _WIN32
#include <windows.h> 
#endif // _WIN32

#ifdef __linux__
#include <boost/filesystem.hpp>
#endif // __linux__

using namespace cv;
using namespace std;

class IMUData {
public:
	IMUData(const double &gx, const double &gy, const double &gz,
		const double &ax, const double &ay, const double &az,
		const double &t) : _g(gx, gy, gz), _a(ax, ay, az), _t(t) {}

	string toString()
	{
		string ret;

		ret += to_string(long long(_t * 1e6) * 1000) + ',';
		ret += to_string(_g[0]) + ',';
		ret += to_string(_g[1]) + ',';
		ret += to_string(_g[2]) + ',';
		ret += to_string(_a[0]) + ',';
		ret += to_string(_a[1]) + ',';
		ret += to_string(_a[2]);

		return ret;
	}

	string toStringM()
	{
		string ret;

		ret += to_string(long long(_t * 1e6) * 1000) + ',';
		ret += to_string(_g[0]) + ',';
		ret += to_string(_g[1]) + ',';
		ret += to_string(_g[2]) + ',';
		ret += to_string(-_a[0]) + ',';
		ret += to_string(-_a[1]) + ',';
		ret += to_string(-_a[2]);

		return ret;
	}

	// Raw data of imu
	Vec3d _g;    //gyr data
	Vec3d _a;    //acc data
	double _t;   //timestamp
};

void LoadFrameNames(const string &strFramesFile, vector<long long> &vFrames);
bool LoadImus2(const string &strAccelGyroFile, vector<IMUData> &vImus);

const char* keys =
"{ help h |  | Print help message. }"
"{ videoName | D:/Datasets/ARCNA/2019-02-08T14-26-03/Frames.m4v          | Video File Name. }";

int main(int argc, char* argv[])
{
	CommandLineParser parser(argc, argv, keys);
	string videoName = parser.get<String>("videoName");

	VideoCapture cap(videoName);

	if (!cap.isOpened())
	{
		cerr << "Error when reading video";
		return -1;
	}

	string workDir = videoName;
	workDir.resize(workDir.size() - 10);

#ifdef _WIN32
	CreateDirectoryA((workDir + "cam0").c_str(), NULL);
#endif // _WIN32

#ifdef __linux__
	boost::filesystem::create_directories((workDir + "cam0").c_str());
#endif // __linux__

	string framesFileName = videoName;
	auto cb = framesFileName.end();
	*(--cb) = 't';
	*(--cb) = 'x';
	*(--cb) = 't';

	vector<long long> vFrames;
	LoadFrameNames(framesFileName, vFrames);
	int nImages = vFrames.size();
	
	cout << "Image converting: [0 - 100%]" << endl;
	cout << "[                                                                                                    ]" << endl;
	cout << " ";

	Mat frame;
	for (int i = 0, n = 1; i < nImages; ++i)
	{
		if (!cap.read(frame))
			break;

		string imgName = workDir + "cam0/" + to_string(vFrames[i]) + ".jpg";
		imwrite(imgName, frame);

		if (i + 1 >= (nImages / 100.) * n)
		{
			cout << ".";
			++n;
		}
	}

	cout << " " << endl;

	//-----------------------------------------------------------------------------
	vector<IMUData> vImus;
	string accGyroFile = workDir + "accel-gyro.txt";
	if(LoadImus2(accGyroFile, vImus))
	{
		int nImus = vImus.size();

		string newImuName = workDir;
		newImuName += "imu0.csv";
		ofstream fOutImu;
		fOutImu.open(newImuName.c_str(), std::ofstream::out | std::ofstream::trunc);
		for (int ni = 0; ni < nImus; ni++)
		{
			fOutImu << vImus[ni].toString() << "\n";
		}
		fOutImu.close();
	}
	//-----------------------------------------------------------------------------

	return 0;
}
void LoadFrameNames(const string &strFramesFile, vector<long long> &vFrames)
{
	ifstream fFrames;
	fFrames.open(strFramesFile.c_str());

	vFrames.reserve(10000);

	while (!fFrames.eof())
	{
		string s;
		getline(fFrames, s);
		if (!s.empty())
		{
			stringstream ss;
			ss << s;

			string s2;
			getline(ss, s2, ',');

			double t = std::stod(s2);
			long long it = (long long)(t * 1e6);
			it = it * 1000;
			vFrames.push_back(it);
		}
	}

	fFrames.close();
}

bool LoadImus2(const string &strAccelGyroFile, vector<IMUData> &vImus)
{
	ifstream fImus(strAccelGyroFile.c_str());
	if (!fImus)
		return false;
	vImus.reserve(40000);
	while (!fImus.eof())
	{
		string s;
		getline(fImus, s);
		if (!s.empty())
		{
			char c = s.at(0);
			if (c<'0' || c>'9')
				continue;

			stringstream ss;
			ss << s;
			double tmpd;
			int cnt = 0;
			double data[10];    // timestamp, wx,wy,wz, ax,ay,az
			while (ss >> tmpd)
			{
				data[cnt] = tmpd;
				cnt++;
				if (cnt == 7)
					break;
				if (ss.peek() == ',' || ss.peek() == ' ')
					ss.ignore();
			}
			//data[0] *= 1e-9;
			IMUData imudata(data[1], data[2], data[3],
				data[4], data[5], data[6], data[0]);
			vImus.push_back(imudata);
		}
	}
	return true;
}
