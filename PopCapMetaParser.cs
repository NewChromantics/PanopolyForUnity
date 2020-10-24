using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace PopCap
{
	[System.Serializable]
	public struct H264EncoderParams_Meta
	{
		public int AverageKbps;
		public int BSlicedThreads;
		public bool CpuOptimisations;
		public bool Deterministic;
		public int EncoderThreads;
		public int LookaheadThreads;
		public int MaxFrameBuffers;
		public int MaxKbps;
		public int MaxSliceBytes;
		public bool MaximisePowerEfficiency;
		public int ProfileLevel;
		public float Quality;
		public bool Realtime;
		public bool VerboseDebug;
	};

	[System.Serializable]
	public struct YuvEncoderParams_Meta
	{
		public int ChromaRangeCount;
		public int DepthMaxMm;
		public int DepthMinMm;
		public bool PingPongLuma;
	};
	
	
	[System.Serializable]
	public struct TFrameMeta
	{
		public int QueuedH264Packets;   //	at the time, number of h264 packets that were queued
		public string CameraName;
		public string Stream;
		public int DataSize;        //	this is the h264 packet size
		public int OutputTimeMs;        //	time the packet was sent to network/file
		public H264EncoderParams_Meta EncoderParams;
		public YuvEncoderParams_Meta YuvEncodeParams;
		public int FrameTimeMs;
		public int Time;
		public int YuvEncode_StartTime;
		public int YuvEncode_DurationMs;

		//	kinect azure meta 
		public Vector3 Accelerometer;
		public Vector3 Gyro;
		public Matrix4x4 LocalToLensTransform;
		public float MaxFov;
		public float Temperature;
		//	projection matrix values
		public float codx;
		public float cody;
		public float cx;
		public float cy;
		public float fx;
		public float fy;
		public float k1;
		public float k2;
		public float k3;
		public float k4;
		public float k5;
		public float k6;
		public float metric_radius;
		public float p1;
		public float p2;

		//	data sent to encoder we dont care about
		public int ChromaUSize;
		public int ChromaVSize;
		public string Format;   //	original input from camera
		public int Width;
		public int Height;
		public bool Keyframe;
		public int LumaSize;
	};

}
