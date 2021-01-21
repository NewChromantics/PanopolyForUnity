using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "BlitChain", menuName = "Panopoly/BlitChain", order = 1)]
public class BlitChain : ScriptableObject
{
    public List<Material> Blitters;

    RenderTexture BackBuffer;
    RenderTexture FrontBuffer;

   
    public void Blit(Texture Input,RenderTexture Output,System.Action<Material> SetUniforms)
    {
        if (BackBuffer == null)
          BackBuffer = new RenderTexture(Output);
        if (FrontBuffer == null)
          FrontBuffer = new RenderTexture(Output);

        Graphics.Blit(Input, FrontBuffer);
        for ( int i=0;  i<Blitters.Count;   i++ )
		{
            var Blitter = Blitters[i];
            if (Blitter == null)
                continue;
            Graphics.Blit( FrontBuffer, BackBuffer);
            SetUniforms(Blitter);
            Graphics.Blit(BackBuffer, FrontBuffer, Blitter);
        }
        Graphics.Blit(FrontBuffer, Output);

        //BackBuffer.Release();
        //FrontBuffer.Release();
    }
}
