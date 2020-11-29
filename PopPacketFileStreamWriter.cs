using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PopPacketFileStreamWriter : MonoBehaviour
{
	public string Filename = "Assets/Capture.PopCap";
	public bool Append = true;

	public readonly static byte[] PacketDelin = PopPacketFileStreamParser.PacketDelin;

	System.IO.FileStream File;

	void OnDisable()
	{
		if (File != null)
		{
			File.Close();
			File = null;
		}
	}

	void Write(byte[] Data)
	{
		//	needed as these funcs can be called whilst disabled
		if (!this.enabled)
			return;

		if ( File == null )
		{
			File = new System.IO.FileStream(Filename, Append ? System.IO.FileMode.Append : System.IO.FileMode.OpenOrCreate );
		}
		File.Write(Data, 0, Data.Length);
	}

	public void WriteBinary(byte[] Data)
	{
		Write(PacketDelin);
		Write(Data);
	}

	public void WriteString(string Data)
	{
		//	convert to binary
		var DataBytes = System.Text.Encoding.UTF8.GetBytes(Data);
		WriteBinary(DataBytes);
	}
}
