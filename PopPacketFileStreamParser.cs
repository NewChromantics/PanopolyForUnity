using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace Pop
{
	[System.Serializable]
	public class UnityEvent_PacketBinary : UnityEngine.Events.UnityEvent<byte[]> { };

	[System.Serializable]
	public class UnityEvent_PacketString : UnityEngine.Events.UnityEvent<string> { };
}

public class PopPacketFileStreamParser : MonoBehaviour
{
	public Pop.UnityEvent_PacketBinary OnPacketBinary;
	public Pop.UnityEvent_PacketString OnPacketString;
	public bool VerboseDebug = false;
	List<byte> PendingData;
	bool PendingDataHasNoMarker = false;	//	set this to true whenever a search fails. Reset it when new data arrives (could store offset to where we last checked)

	//	gr: queue up data, don't process now, so we can throttle, or allow multithread access
	public void OnFileChunk(byte[] Data)
	{
		if (PendingData == null)
			PendingData = new List<byte>();
		PendingData.AddRange(Data);
		//	reset marker knowledge
		PendingDataHasNoMarker = false;
	}

	public readonly static byte[] PacketDelin = new byte[] { (byte)'P', (byte)'o', (byte)'p', (byte)'\n' };
	
	int GetNextPacketStart(int FromPosition=0)
	{
		//	gr: this needs to be a tight loop.
		//		can we cast to uint32 and compare with one op?
		//	gr: is the list[] accessor slow? should PendingData turn into an array of byte[] ?
		//	gr: iirc there's a speedup caching .count...
		for (; FromPosition< PendingData.Count - 4; FromPosition++)
		{
			if (PendingData[FromPosition + 0] != PacketDelin[0]) continue;
			if (PendingData[FromPosition + 1] != PacketDelin[1]) continue;
			if (PendingData[FromPosition + 2] != PacketDelin[2]) continue;
			if (PendingData[FromPosition + 3] != PacketDelin[3]) continue;
			return FromPosition;
		}

		throw new System.Exception("Found no next packet marker");
	}

	byte[] PopNextPacket()
	{
		//	we know there is no packet, skip search
		if (PendingDataHasNoMarker)
			return null;

		var NextPacketStartPosition = GetNextPacketStart();
		var SourceStart = NextPacketStartPosition + PacketDelin.Length;
		var NextPacketEndPosition = GetNextPacketStart(SourceStart);
		var Packet = new byte[NextPacketEndPosition - SourceStart];
		var TargetStart = 0;
		PendingData.CopyTo(SourceStart, Packet, TargetStart, Packet.Length);

		//	delete all the data up to next packet
		PendingData.RemoveRange(0, NextPacketEndPosition);
		return Packet;
	}

	//	return if more data to process
	bool ProcessNextData()
	{
		byte[] Packet;
		try
		{
			Packet = PopNextPacket();
			if (Packet == null)
				return false;
		}
		catch (System.Exception e)
		{
			//	assuming "No marker found"
			PendingDataHasNoMarker = true;
			return false;
		}

		try
		{
			ParsePacket(Packet);
		}
		catch(System.Exception e)
		{
			Debug.LogError("Error parsing packet " + e.Message);
		}
		return true;
	}

	bool IsStringData(byte[] Data)
	{
		if ( Data.Length == 0)
			return false;

		//	check for some chars
		char Data0 = (char)Data[0];
		switch(Data0)
		{
			case '{':
				return true;

			default:
				return false;
		}
	}

	void ParsePacket(byte[] Data)
	{
		//	work out if its json meta or h264 packet and call event
		if (IsStringData(Data) )
		{
			var DataString = System.Text.Encoding.UTF8.GetString(Data);
			if (VerboseDebug)
				Debug.Log("Packet: " + DataString);
			OnPacketString.Invoke(DataString);
		}
		else
		{
			if (VerboseDebug)
				Debug.Log("Packet bytes: x" + Data.Length);
			OnPacketBinary.Invoke(Data);
		}
	}

	void Update()
	{
		if ( PendingData == null )
		{
			Debug.LogWarning("Waiting for first data");
			return;
		}

		while (true)
		{
			if (!ProcessNextData())
				break;
		}
	}
}
