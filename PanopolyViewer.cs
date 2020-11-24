using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using PopCap;
using Panopoly;
using Pop;

namespace Panopoly
{
	[System.Serializable]
	public class UnityEvent_ColourAndDepthAndTime : UnityEngine.Events.UnityEvent<Texture, Texture, int> { }
	public class UnityEvent_Texture : UnityEngine.Events.UnityEvent<Texture> { }

	public struct TFrameData
	{
		public PopCap.TFrameMeta Meta;
		public byte[] Data;
	}

	public struct TDecodedFrame
	{
		public List<Texture2D> FramePlaneTextures;
		public List<Pop.PixelFormat> FramePlaneFormats;
		public PopCap.TFrameMeta Meta;
		public int FrameTime;
	}

	public class TStream
	{
		public bool					VerboseDebug { get { return PanopolyViewer.StreamVerboseDebug; } }
		public string				Name;
		PopH264.Decoder				Decoder;
		public PopH264.DecoderParams DecoderParams;
		public bool					ThreadedDecoding = true;
		List<TFrameData>			PendingFrames = new List<TFrameData>();
		TDecodedFrame?				LastDecodedFrame = null;	//	saved for BlitEveryFrame. maybe store in PanopolyViewer. This is the last decoded frame we returned.
		TDecodedFrame?				NextDecodedFrame = null;    //	last frame we decoded which was in the future

		Dictionary<int, PopCap.TFrameMeta> FrameMetas = new Dictionary<int, TFrameMeta>();  //	hack: we're ditching old data, but need to fetch meta back again later
		int FrameCounter = 0;		//	gr: PopH264, osx at least, isn't returning correct frame numbers

		public TStream(string Name,PopH264.DecoderParams DecoderParams)
		{
			this.Name = Name;
			this.DecoderParams = DecoderParams;
			//	gr: continue even if we fail to create a decoder to aid flow testing
			try
			{
				Decoder = new PopH264.Decoder(DecoderParams, ThreadedDecoding);
			}
			catch(System.Exception e)
			{
				Debug.LogError("Failed to allocated PopH264 decoder: " + e.Message);
			}
		}

		public void PushFrame(PopCap.TFrameMeta Meta,byte[] Data)
		{
			var Frame = new TFrameData();
			Frame.Meta = Meta;
			Frame.Data = Data;
			PendingFrames.Add(Frame);
		}

		public void DecodeToTime(int Millseconds)
		{
			//	todo: if in past, rewind to last keyframe <= Milliseconds and re-push pending frames

			//	push any frame up to this time
			while ( PendingFrames.Count > 0 )
			{
				var Frame = PendingFrames[0];
				if (Frame.Meta.Time > Millseconds)
					break;
				if (Decoder != null)
				{
					if (VerboseDebug)
					{
						Debug.Log("Stream " + Name + " decoding data x" + Frame.Data.Length + " Framenumber #" + FrameCounter);
					}
					Decoder.PushFrameData(Frame.Data, FrameCounter);
					FrameMetas[FrameCounter] = Frame.Meta;
					FrameCounter++;
				}
				PendingFrames.RemoveAt(0);
			}
		}

		//	get new textures, meta for this time. LastFrame is the last decoded frame that was returned
		public TDecodedFrame? GetFrameToTime(int Milliseconds,bool ReturnLastFrameIfNotNew)
		{
			System.Func<TDecodedFrame?> NoFrame = () => { return ReturnLastFrameIfNotNew ? LastDecodedFrame : null; };

			if (Decoder == null)
				return NoFrame();

			//	avoid infinite loop if say, timestamps are bad
			int Tries = 20;
			while (Tries-->0)
			{
				//	already have a next frame, and it's too far in the future
				if (NextDecodedFrame.HasValue)
				{
					if (NextDecodedFrame.Value.FrameTime > Milliseconds)
					{
						if (VerboseDebug)
							Debug.Log("Stream " + Name + " next frame in future: " + NextDecodedFrame.Value.FrameTime + ">"+Milliseconds);
						return NoFrame();
					}

					//	got next frame and it's spot on
					if (NextDecodedFrame.Value.FrameTime == Milliseconds)
					{
						LastDecodedFrame = NextDecodedFrame;
						NextDecodedFrame = null;
						return LastDecodedFrame;
					}

					//	NextDecodedFrame must be in the past
					//	if ( LastDecodedFrame!=null ) skipped frame
					LastDecodedFrame = NextDecodedFrame;
				}

				//	gr: should this always be LastDecodedFrame?
				var PrevFrame = NextDecodedFrame.HasValue ? NextDecodedFrame : NoFrame();

				//	decode next frame
				var NewFrame = new TDecodedFrame();
				var NewFrameTime = Decoder.GetNextFrame(ref NewFrame.FramePlaneTextures, ref NewFrame.FramePlaneFormats);
				if (!NewFrameTime.HasValue)
				{
					if (VerboseDebug)
						Debug.Log("Stream " + Name + " no frame");

					return PrevFrame;
				}
				if (VerboseDebug)
					Debug.Log("Stream " + Name + " decoded frame #" + NewFrameTime.Value + "(last sent=" + (FrameCounter - 1) +" )");
				if ( FrameMetas.ContainsKey(NewFrameTime.Value))
				{
					NewFrame.Meta = FrameMetas[NewFrameTime.Value];
				}
				else
				{
					Debug.LogError("Missing meta for new frame " + NewFrameTime.Value);
				}

				//	set this as next frame and loop around
				NextDecodedFrame = NewFrame;
			}

			Debug.LogError("Aborting after X tries of decoding frame in stream "+ Name);
			return NoFrame();
		}
	};
}



public class PanopolyViewer : MonoBehaviour
{
	public bool VerboseDebug = false;

	[Range(0, 30)]
	public float TimeSecs = 0;
	public int TimeMs { get { return (int)(TimeSecs * 1000.0f); } }
	int? FirstTimeMs = null;

	[Range(0, 1000)]
	public int DecodeAheadMs = 100;

	Dictionary<string, TStream> Streams = new Dictionary<string, TStream>();
	public PopH264.DecoderParams DecoderParams;

	public List<string> TextureUniformNames;

	[Header("Temporary hardcoded colour & depth outputs")]
	public RenderTexture ColourBlitTarget;
	public Material ColourBlitMaterial;
	public RenderTexture DepthBlitTarget;
	public Material DepthBlitMaterial;
	public UnityEvent_Texture OnColourUpdated;
	public UnityEvent_Texture OnDepthUpdated;

	[Header("To aid debugging material/shader")]
	public bool BlitEveryFrame = false;

	static public bool StreamVerboseDebug = false;

	PopCap.TFrameMeta? PendingMeta = null;  //	meta preceding next data


	TStream GetStream(string Name)
	{
		if (!Streams.ContainsKey(Name))
			Streams.Add(Name, new TStream(Name,DecoderParams));
		return Streams[Name];
	}
	

	

	public void OnMeta(string StringPacket)
	{
		var Meta = PopCap.TFrameMeta.Parse(StringPacket);
		OnMeta(Meta);
	}

	public void OnMeta(PopCap.TFrameMeta Meta)
	{
		if (!FirstTimeMs.HasValue)
			FirstTimeMs = Meta.Time;

		if (PendingMeta.HasValue)
		{
			Debug.LogWarning("Stream "+ PendingMeta.Value.StreamName+" has pending meta, but didn't get data (should pass on meta to stream without data?)",this );
		}
		PendingMeta = Meta;
		
	}


	public void OnData(byte[] Data)
	{
		//	todo: this function should allow multiple parts? or caller should assemble multiple packets?
		if (!PendingMeta.HasValue)
			throw new System.Exception("Recieved data without preceding meta");

		var Meta = PendingMeta.Value;
		var Stream = GetStream(Meta.StreamName);
		Stream.PushFrame(PendingMeta.Value, Data);

		PendingMeta = null;
	}


	void UpdateClock()
	{
		//	if using external clock, don't change
		//	if using Latest-frame, find latest sync'd frame and set clock to that
		//	else do nothing
	}

	void Update()
	{
		StreamVerboseDebug = VerboseDebug;
		UpdateClock();
		UpdateDecode();
		UpdateFrame();
	}

	bool IsDepthStream(PopCap.TFrameMeta Meta,List<Pop.PixelFormat> FramePixelFormats)
	{
		//	go by stream name
		if ( !string.IsNullOrEmpty(Meta.StreamName) )
		{
			if (Meta.StreamName.Contains("reyscale"))
				return false;
			return true;
		}

		Debug.Log("Unnamed stream, pixelformat0=" + FramePixelFormats[0].ToString());
		return true;
	}


	void UpdateDecode()
	{
		var DecodeTime = this.TimeMs + DecodeAheadMs;
		foreach (KeyValuePair<string, TStream> NameAndStream in Streams)
		{
			var StreamName = NameAndStream.Key;
			var Stream = NameAndStream.Value;
			Stream.DecodeToTime(DecodeTime);
		}
	}

	void UpdateFrame()
	{
		//	get latest frames from each stream
		//	gr: try and keep these in sync, UpdateClock() should do it, it should figure out the sync'd frame we should be displaying
		var FrameTime = this.TimeMs;
		foreach (KeyValuePair<string,TStream> NameAndStream in Streams)
		{
			var StreamName = NameAndStream.Key;
			var Stream = NameAndStream.Value;
			var NewFrame = Stream.GetFrameToTime(FrameTime, BlitEveryFrame);
			if (!NewFrame.HasValue)
				continue;

			//	hard coded blit routine
			var IsDepth = IsDepthStream(NewFrame.Value.Meta, NewFrame.Value.FramePlaneFormats);

			if (IsDepth)
				UpdateBlitDepth(NewFrame.Value);
			else
				UpdateBlitColour(NewFrame.Value);
		}

		/*
		//	gr this needs to sync with frame output
		//	maybe this component should just blit, then send complete texture with timecode to something else
		var mr = GetComponent<MeshRenderer>();
		if ( mr != null )
			UpdateMaterial( mr.sharedMaterial, Meta.YuvEncodeParams, FramePlaneTextures, TextureUniformNames);
		UpdateBlit(NewFrameNumber.Value,Meta.YuvEncodeParams, FramePlaneTextures, TextureUniformNames);
		*/
	}

	void UpdateBlitDepth(TDecodedFrame Frame)
	{
		var BlitTarget = DepthBlitTarget;
		var BlitMaterial = DepthBlitMaterial;
		var OnBlit = OnDepthUpdated;

		if (BlitTarget == null || BlitMaterial == null)
			return;

		UpdateMaterial(BlitMaterial, Frame.Meta.YuvEncodeParams, Frame.FramePlaneTextures, TextureUniformNames);

		Graphics.Blit(null, BlitTarget, BlitMaterial);
		if ( OnBlit != null)
			OnBlit.Invoke(BlitTarget);
	}


	void UpdateBlitColour(TDecodedFrame Frame)
	{
		var BlitTarget = ColourBlitTarget;
		var BlitMaterial = ColourBlitMaterial;
		var OnBlit = OnColourUpdated;

		if (BlitTarget == null || BlitMaterial == null)
			return;

		UpdateMaterial(BlitMaterial, Frame.Meta.YuvEncodeParams, Frame.FramePlaneTextures, TextureUniformNames);

		Graphics.Blit(null, BlitTarget, BlitMaterial);
		if ( OnBlit != null )
			OnBlit.Invoke(BlitTarget);
	}


	void UpdateMaterial(Material material,YuvEncoderParams_Meta EncoderParams, List<Texture2D> Planes, List<string> PlaneUniforms)
	{
		material.SetFloat("Encoded_DepthMinMetres", EncoderParams.DepthMinMm / 1000);
		material.SetFloat("Encoded_DepthMaxMetres", EncoderParams.DepthMaxMm / 1000);
		material.SetInt("Encoded_ChromaRangeCount", EncoderParams.ChromaRangeCount);
		material.SetInt("Encoded_LumaPingPong", EncoderParams.PingPongLuma ? 1 : 0);
		material.SetInt("PlaneCount", Planes.Count);

		for ( var i=0;	i<Mathf.Min(Planes.Count,PlaneUniforms.Count);	i++ )
		{
			material.SetTexture(PlaneUniforms[i], Planes[i]);
		}
	}
}
