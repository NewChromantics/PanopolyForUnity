using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PointCloudRayMarch : MonoBehaviour
{
	public Material RayMarchMaterial;

	public void OnFrame(PopCap.TFrameMeta ColourMeta, Texture ColourTexture, PopCap.TFrameMeta DepthMeta, Texture PositionTexture)
	{
		//RayMarchMaterial.SetTexture("CloudPositions")
		RayMarchMaterial.SetVector("CameraToLocalViewportMin", DepthMeta.Camera.GetCameraSpaceViewportMin());
		RayMarchMaterial.SetVector("CameraToLocalViewportMax", DepthMeta.Camera.GetCameraSpaceViewportMax());
		RayMarchMaterial.SetMatrix("CameraToLocalTransform", DepthMeta.Camera.GetCameraToLocal());
		RayMarchMaterial.SetMatrix("LocalToCameraTransform", DepthMeta.Camera.GetLocalToCamera());
		RayMarchMaterial.SetMatrix("WorldToLocalTransform", DepthMeta.Camera.GetWorldToLocal());
	}
}
