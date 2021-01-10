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
		public float[] Intrinsics;					//	3x3 matrix (fx 0 cx, 0 fy cy)
		public float[] IntrinsicsCameraResolution;  //	w x h x depth unit
		public float[] LocalEulerRadians;


		//	gr: this is currently transposed (column major in ARkit). Next version will be in a different struct/variable and this will be deprecated
		//	this is arcamera.transform. Multiply a world space position by this, to get camera space pos out (for anchors)
		//	therefore, it is world to local[camera]
		public float[] LocalToWorld;

		public float[] ProjectionMatrix;        //	may be 3x3, should be corrected in capture in future. Column major, needs transposing
		public string Tracking;                 //	state
		public string TrackingStateReason;
		public bool ARWorldAlignmentGravity { get { return true; } } //	gr: currently always set to ARWorldAlignmentGravity

		public Matrix4x4 ProjectionMatrix4x4
		{
			get
			{
				if (ProjectionMatrix == null || ProjectionMatrix.Length != 4 * 4)
					throw new System.Exception("requested ProjectionMatrix4x4, but no projection matrix");

				var Row0 = new Vector4(ProjectionMatrix[0], ProjectionMatrix[1], ProjectionMatrix[2], ProjectionMatrix[3]);
				var Row1 = new Vector4(ProjectionMatrix[4], ProjectionMatrix[5], ProjectionMatrix[6], ProjectionMatrix[7]);
				var Row2 = new Vector4(ProjectionMatrix[8], ProjectionMatrix[9], ProjectionMatrix[10], ProjectionMatrix[11]);
				var Row3 = new Vector4(ProjectionMatrix[12], ProjectionMatrix[13], ProjectionMatrix[14], ProjectionMatrix[15]);

				var Transform = new Matrix4x4();
				Transform.SetColumn(0, Row0);
				Transform.SetColumn(1, Row1);
				Transform.SetColumn(2, Row2);
				Transform.SetColumn(3, Row3);
				return Transform;
			}
		}

		public Vector3 GetCameraSpaceViewportMin()
		{
			return new Vector3(0, 0, 0);
		}
		public Vector3 GetCameraSpaceViewportMax()
		{
			//	ios depth in mm
			//	this width/height/mm should match the projection matrix values
			if (IntrinsicsCameraResolution == null|| IntrinsicsCameraResolution.Length == 0)
			{
				//	if there is an intrinsic/projection matrix, we can assume size. if we use 1,1 with that, it'll be tiny
				if ( Intrinsics != null && Intrinsics.Length > 4 )
				{
					var fx = Intrinsics[0];
					var fy = Intrinsics[4];
					return new Vector3(fx, fy, 1000);
				}

				//	this will be wrong, but if there is no intrinsic matrix, then these numbers dont matter
				return new Vector3(500, 500, 1000);
			}
			return new Vector3(IntrinsicsCameraResolution[0], IntrinsicsCameraResolution[1], 1000);
		}

		public static Matrix4x4 ReconstructMatrix(Matrix4x4 RightHandMatrix)
		{
			var Translation = __GetPosition(RightHandMatrix);
			var Rotation = __GetRotation(RightHandMatrix);
			return Matrix4x4.TRS(Translation, Rotation, Vector3.one);
		}

		//  https://github.com/sacchy/Unity-Arkit/blob/master/Assets/Plugins/iOS/UnityARKit/Utility/UnityARMatrixOps.cs
		public static Vector3 __GetPosition(Matrix4x4 matrix)
		{
			// Convert from ARKit's right-handed coordinate
			// system to Unity's left-handed

			var InvertZ = new Matrix4x4();
			InvertZ.SetRow(0, new Vector4(1, 0, 0, 0));
			InvertZ.SetRow(1, new Vector4(0, 1, 0, 0));
			InvertZ.SetRow(2, new Vector4(0, 0, -1, 0));
			InvertZ.SetRow(3, new Vector4(0, 0, 0, 1));

			matrix = matrix * InvertZ;

			Vector3 position = matrix.GetRow(3);
			//position.z = -position.z;


			return position;
		}

		//  https://github.com/sacchy/Unity-Arkit/blob/master/Assets/Plugins/iOS/UnityARKit/Utility/UnityARMatrixOps.cs
		public static Quaternion __GetRotation(Matrix4x4 matrix)
		{
			// Convert from ARKit's right-handed coordinate
			// system to Unity's left-handed
			Quaternion rotation = __QuaternionFromMatrix_RowMajor(matrix);
			rotation.z = -rotation.z;
			rotation.w = -rotation.w;

			return rotation;
		}


		//  https://github.com/sacchy/Unity-Arkit/blob/master/Assets/Plugins/iOS/UnityARKit/Utility/UnityARMatrixOps.cs
		static Quaternion __QuaternionFromMatrix_RowMajor(Matrix4x4 m)
		{
			// Adapted from: http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/index.htm
			Quaternion q = new Quaternion();
			//	>	The max( 0, ... ) is just a safeguard against rounding error.
			q.w = Mathf.Sqrt(Mathf.Max(0, 1 + m[0, 0] + m[1, 1] + m[2, 2])) / 2;
			q.x = Mathf.Sqrt(Mathf.Max(0, 1 + m[0, 0] - m[1, 1] - m[2, 2])) / 2;
			q.y = Mathf.Sqrt(Mathf.Max(0, 1 - m[0, 0] + m[1, 1] - m[2, 2])) / 2;
			q.z = Mathf.Sqrt(Mathf.Max(0, 1 - m[0, 0] - m[1, 1] + m[2, 2])) / 2;
			q.x *= Mathf.Sign(q.x * (m[1, 2] - m[2, 1]));
			q.y *= Mathf.Sign(q.y * (m[2, 0] - m[0, 2]));
			q.z *= Mathf.Sign(q.z * (m[0, 1] - m[1, 0]));
			return q;
		}


		public Matrix4x4 GetLocalToWorld()
		{
			if (LocalToWorld == null || LocalToWorld.Length == 0 )
				return Matrix4x4.identity;

			var Row0 = new Vector4(LocalToWorld[0], LocalToWorld[1], LocalToWorld[2], LocalToWorld[3]);
			var Row1 = new Vector4(LocalToWorld[4], LocalToWorld[5], LocalToWorld[6], LocalToWorld[7]);
			var Row2 = new Vector4(LocalToWorld[8], LocalToWorld[9], LocalToWorld[10], LocalToWorld[11]);
			var Row3 = new Vector4(LocalToWorld[12], LocalToWorld[13], LocalToWorld[14], LocalToWorld[15]);

			//	gr: constructor takes COLUMNS, the input data here is column major (from arkit)
			var Transform = new Matrix4x4();
			Transform.SetColumn(0, Row0);
			Transform.SetColumn(1, Row1);
			Transform.SetColumn(2, Row2);
			Transform.SetColumn(3, Row3);

			//	convert right hand to left, but can't quite do it in one multiply, so rebuilding matrix (which is stable)
			Transform = ReconstructMatrix(Transform);

			return Transform;
		}

		public Matrix4x4 GetWorldToLocal()
		{
			var LocalToWorld = GetLocalToWorld();
			return LocalToWorld.inverse;
		}


		//	projection matrix
		//	converts local space to image space, IntrinsicsCameraResolution, not 0..1
		//	todo: make source transform to uv space
		public Matrix4x4 GetCameraToLocal()
		{
			if ( Intrinsics == null || Intrinsics.Length == 0 )
			{
				//	fallback
				//	to match arkit, make sure we have a center so the data is expected to be -1...1
				//return Matrix4x4.identity;
				var WidthHeightDepth = GetCameraSpaceViewportMax();
				var Def_fx = WidthHeightDepth.x;
				var Def_fy = WidthHeightDepth.y;
				var Def_cx = WidthHeightDepth.x / 2.0f;
				var Def_cy = WidthHeightDepth.y / 2.0f;
				Intrinsics = new float[6] {
					Def_fx,	0,		Def_cx,
					0,		Def_fy,	Def_cy
				};
			}

			//	from 3x3 intrinsics matrix
			//	fx 0 cx
			//	0 fy cy
			//	0 0 1000?
			float fx = Intrinsics[0];
			float fy = Intrinsics[4];
			float cx = Intrinsics[2];
			float cy = Intrinsics[5];

			//	is this just the inverse of a/the projection matrix?
			Vector4 CameraToLocalRow0 = new Vector4(1.0f / fx, 0, -cx / fx, 0); //	opposite of (fx, 0, -cx, 0)
			Vector4 CameraToLocalRow1 = new Vector4(0, 1.0f / fy, -cy / fy, 0);
			Vector4 CameraToLocalRow2 = new Vector4(0, 0, 1, 0);
			Vector4 CameraToLocalRow3 = new Vector4(0, 0, 0, 1);
			var CameraToLocal = new Matrix4x4();
			CameraToLocal.SetRow(0, CameraToLocalRow0);
			CameraToLocal.SetRow(1, CameraToLocalRow1);
			CameraToLocal.SetRow(2, CameraToLocalRow2);
			CameraToLocal.SetRow(3, CameraToLocalRow3);
			/*
			if (this.ProjectionMatrix != null && this.ProjectionMatrix.Length > 0)
			{
				var p = ProjectionMatrix4x4.inverse;
				//if (ProjectionMatrix != null && ProjectionMatrix.Length == 4 * 4)
				//	return ProjectionMatrix4x4.inverse;
				//Debug.Log("Use projection matrix");
				return p;
			}
			*/

			return CameraToLocal;
			/*	this is how it's used
			float4 CameraPosition4;
			CameraPosition4.x = CameraPosition.x;
			CameraPosition4.y = CameraPosition.y;
			CameraPosition4.z = 1;
			CameraPosition4.w = 1 / Depth;  //	scale all by depth, this is undone by /w hence 1/z

			float4 LocalPosition4 = mul(CameraToLocal, CameraPosition4);
			float3 LocalPosition = LocalPosition4.xyz / LocalPosition4.www;
			*/
		}

		//	projection matrix inverse, convert image-space (0..w, not 0..1) coordinates
		public Matrix4x4 GetLocalToCamera()
		{
			/*
			if (this.ProjectionMatrix != null && this.ProjectionMatrix.Length > 0)
			{
				//Debug.Log("Use projection matrix");
				return this.ProjectionMatrix4x4;
			}
			*/
			var CameraToLocal = GetCameraToLocal();
			var LocalToCamera = CameraToLocal.inverse;
			return LocalToCamera;
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
		public H264EncoderParams_Meta EncoderParams;
		public YuvEncoderParams_Meta YuvEncodeParams;
		public int OutputTimeMs;        //	time the packet was sent to network/file
		public int FrameTimeMs;
		public int Time;
		public int TimeMs;
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


		void FixStreamName()
		{
			if (string.IsNullOrEmpty(StreamName))
			{
				StreamName = Stream;
			}
			if (string.IsNullOrEmpty(StreamName))
			{
				Debug.LogWarning("Frame JSON with no streamname");
			}
		}

		void FixProjectionMatrix()
		{
			//	always need a camera object
			if (Camera == null)
				Camera = new TCamera();
		}


		static public TFrameMeta Parse(string Json)
		{
			var This = JsonUtility.FromJson<PopCap.TFrameMeta>(Json);
			//	backwards compatibility from old formats
			This.FixStreamName();
			This.FixProjectionMatrix();
			return This;
		}

		public int GetFrameTimeMs()
		{
			//	gr: fallbacks for old formats etc
			if (Time!=0)
				return Time;

			if (TimeMs!=0)
				return TimeMs;

			if (FrameTimeMs!=0)
				return FrameTimeMs;

			//	gr: we need to make sure 0 isn't actually 0ms, compared to uninitialised 0
			return OutputTimeMs;
		}
	};



}
