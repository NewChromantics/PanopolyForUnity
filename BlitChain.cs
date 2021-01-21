using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "BlitChain", menuName = "Panopoly/BlitChain", order = 1)]
public class BlitChain : ScriptableObject
{
    public List<Material> Blitters;

    RenderTexture BufferA;
   
    public void Blit(Texture Input,RenderTexture Output,System.Action<Material> SetUniforms)
    {
        if (BufferA == null)
            BufferA = new RenderTexture(Output);
        
        //  alternate front & back
        Texture Back = null;
        RenderTexture Front = null;

        for ( int i=0;  i<Blitters.Count;   i++ )
		{
            var Blitter = Blitters[i];
            if (Blitter == null)
                continue;

            //  back buffer flip
            //  not rendered to front yet, back should be input
            if (Front == null)
            {
                Back = Input;
                //  gr: little trick, if we have an EVEN number of blits, blit to BufferA first and
                //      the last front should be output. (assuming no null blitters)
                bool EvenNumberOfBlits = (Blitters.Count % 2) == 0;
                Front = EvenNumberOfBlits ? BufferA : Output;
            }
            else // flip
			{
                Back = Front;
                Front = (Back == Output) ? BufferA : Output;
			}

            //Graphics.Blit(Source, BackBuffer);
            SetUniforms(Blitter);

            Graphics.Blit(Back, Front, Blitter);
        }
        if (Front != Output)
        {
            Graphics.Blit(Front, Output);
            Debug.Log("Extra blit to output Blitters.Count=" + Blitters.Count);
        }

        //BackBuffer.Release();
        //FrontBuffer.Release();
    }
}
