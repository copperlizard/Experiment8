using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaterHeightCalculator : MonoBehaviour
{
    [SerializeField]
    private Material m_waterMaterial;

    [SerializeField]
    private ComputeShader m_computeShader;

    private RenderTexture m_textureRenderer;
    private Texture2D m_2Dtexture;

    private int m_kernelHandle = 0;

    // Use this for initialization
    void Start ()
    {
        if (m_computeShader == null)
        {
            Debug.Log("m_computeShader not assigned!");
        }

        if (m_waterMaterial == null)
        {
            Debug.Log("m_waterMaterail not assigned!");
        }

        m_kernelHandle = m_computeShader.FindKernel("CSMain");
        m_textureRenderer = new RenderTexture(256, 256, 24);
        m_textureRenderer.enableRandomWrite = true;
        m_textureRenderer.Create();

        m_2Dtexture = new Texture2D(m_textureRenderer.width, m_textureRenderer.height);

        m_computeShader.SetTexture(m_kernelHandle, "Result", m_textureRenderer);
    }
	
	// Update is called once per frame
	void Update ()
    {
        m_computeShader.SetFloat("_Time", Time.realtimeSinceStartup * 0.05f);
        m_waterMaterial.SetFloat("_realTime", Time.realtimeSinceStartup * 0.05f);
        m_computeShader.Dispatch(m_kernelHandle, 256 / 8, 256 / 8, 1);
    }

    public float GetWaveStrength(Vector2 pos)
    {
        RenderTexture.active = m_textureRenderer;
        m_2Dtexture.ReadPixels(new Rect(0, 0, m_textureRenderer.width, m_textureRenderer.height), 0, 0);
        m_2Dtexture.Apply();

        //Need to transform pos to "water space" then scale down to "waterheight texture space" (1/30th I think...)

        

        Color pix = m_2Dtexture.GetPixel((int)(pos.x * 256.0), (int)(pos.y * 256.0));

        return pix.r;
    }
}
