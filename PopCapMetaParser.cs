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
	public struct TAnchor
	{
		public float[] LocalToWorld;
		public string Name;
		public string SessionUuid;
		public string Uuid;
	};

	[System.Serializable]
	public class TCamera
	{
		public float[] Intrinsics;
		public float[] IntrinsicsCameraResolution;  //	wxh
		public float[] LocalEulerRadians;


		//	gr: this is currently transposed (column major in ARkit). Next version will be in a different struct/variable and this will be deprecated
		//	this is arcamera.transform. Multiply a world space position by this, to get camera space pos out (for anchors)
		//	therefore, it is world to local[camera]
		public float[] LocalToWorld;
		
		public float[] ProjectionMatrix;        //	may be 3x3, should be corrected in capture in future. Column major, needs transposing
		public string Tracking;                 //	state
		public string TrackingStateReason;
		public bool ARWorldAlignmentGravity { get { return true; } } //	gr: currently always set to ARWorldAlignmentGravity

		public Vector3 GetCameraSpaceViewportMin()
		{
			return new Vector3(0, 0, 0);
		}
		public Vector3 GetCameraSpaceViewportMax()
		{
			//	ios depth in mm
			return new Vector3(IntrinsicsCameraResolution[0], IntrinsicsCameraResolution[1], 1000);
		}

		public Matrix4x4 GetWorldToLocal()
		{
			var Row0 = new Vector4(LocalToWorld[0], LocalToWorld[1], LocalToWorld[2], LocalToWorld[3]);
			var Row1 = new Vector4(LocalToWorld[4], LocalToWorld[5], LocalToWorld[6], LocalToWorld[7]);
			var Row2 = new Vector4(LocalToWorld[8], LocalToWorld[9], LocalToWorld[10], LocalToWorld[11]);
			var Row3 = new Vector4(LocalToWorld[12], LocalToWorld[13], LocalToWorld[14], LocalToWorld[15]);

			var Transform = new Matrix4x4();
			Transform.SetColumn(0, Row0);
			Transform.SetColumn(1, Row1);
			Transform.SetColumn(2, Row2);
			Transform.SetColumn(3, Row3);
			return Transform;
			/*
			var Transform = new Matrix4x4(Row0, Row1, Row2, Row3);

			//	gr: we're using gravity alignment
			//		see ARWorldAlignmentGravity
			//	we also have z going in the wrong direction
			//		https://developer.apple.com/documentation/arkit/arcamera/2866108-transform?language=objc
			//		and the z - axis points away from the device on the screen side.
			var InvertZ = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(1, 1, -1));
			//Transform = 
			return Transform.transpose;*/
		}

		public Matrix4x4 GetLocalToWorld()
		{
			var WorldToLocal = GetWorldToLocal();
			return WorldToLocal.inverse;
		}

		//	projection matrix
		//	converts local space to image space, IntrinsicsCameraResolution, not 0..1
		//	todo: make source transform to uv space
		public Matrix4x4 GetCameraToLocal()
		{
			//var Row0 = new Vector4(ProjectionMatrix[0], ProjectionMatrix[1], ProjectionMatrix[2], ProjectionMatrix[3]);
			//var Row1 = new Vector4(ProjectionMatrix[4], ProjectionMatrix[5], ProjectionMatrix[6], ProjectionMatrix[7]);
			//var Row2 = new Vector4(ProjectionMatrix[8], ProjectionMatrix[9], ProjectionMatrix[10], ProjectionMatrix[11]);
			//var Row3 = new Vector4(ProjectionMatrix[12], ProjectionMatrix[13], ProjectionMatrix[14], ProjectionMatrix[15]);
			var Row0 = new Vector4(Intrinsics[0], Intrinsics[1], Intrinsics[2], 0);
			var Row1 = new Vector4(Intrinsics[3], Intrinsics[4], Intrinsics[5], 0);
			var Row2 = new Vector4(Intrinsics[6], Intrinsics[7], Intrinsics[8], 0);
			var Row3 = new Vector4(0, 0, 0, 1);
			var Transform = new Matrix4x4(Row0, Row1, Row2, Row3);
			return Transform.transpose;
		}

		//	projection matrix inverse, convert image-space (0..w, not 0..1) coordinates
		public Matrix4x4 GetLocalToCamera()
		{
			var LocalToCamera = GetCameraToLocal();
			return LocalToCamera.inverse;
		}
	};


	[System.Serializable]
	public struct TFrameMeta
	{
		public int QueuedH264Packets;   //	at the time, number of h264 packets that were queued
		//public string CameraName;
		public string Stream;
		public string StreamName;
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

		//	arkit meta
		public TAnchor[] Anchors;
		public TCamera Camera;
		public int FeatureCount;
		public int[] ImageOrigRect;		//	original image size
		public int[] ImageResizeRect;   //	image size encoded as rect of original
		public float LightIntensity;
		public float LightTemperature;

		//	data sent to encoder we dont care about
		public int ChromaUSize;
		public int ChromaVSize;
		public string Format;   //	original input from camera
		public int Width;
		public int Height;
		public bool Keyframe;   //	gr: this may be the requested keyframe state, so may not match NALU/IFrame status
		public int LumaSize;

		static public TFrameMeta Parse(string Json)
		{
			var This = JsonUtility.FromJson<PopCap.TFrameMeta>(Json);
			//	backwards compatibility from old formats
			if ( string.IsNullOrEmpty(This.StreamName) )
			{
				This.StreamName = This.Stream;
			}
			if (string.IsNullOrEmpty(This.StreamName))
			{
				Debug.LogWarning("Frame JSON with no streamname");
			}
			return This;
		}

		public Matrix4x4 GetCameraToLocal()
		{
			if (Camera == null)
				return Matrix4x4.identity;

			if (Camera.ProjectionMatrix == null)
				return Matrix4x4.identity;

			return Camera.GetCameraToLocal();
		}
	};



}
