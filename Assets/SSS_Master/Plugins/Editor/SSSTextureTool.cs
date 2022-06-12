using System.Collections;
using System.Collections.Generic;

using UnityEngine;
using System.IO;
#if UNITY_EDITOR
using UnityEditor;

public class SSSTextureTool : EditorWindow
{
    #region SSS_fuctions
    float Gaussian(float v, float r)
    {
        //v为分母不为0，该高斯函数在v->0的时候极限是0
        if (v == 0)
            return 0;
        return 1.0f / Mathf.Sqrt(2.0f * Mathf.PI * v) * Mathf.Exp(-(r * r) / (2f * v));
    }

    Color Scatter(float r)
    {
        //Coefficients from GPU Gems 3 − Advanced Skin Rendering
        return new Color(0.233f, 0.455f, 0.649f) * Gaussian(0.0064f * 1.414f, r)
           + new Color(0.100f, 0.336f, 0.344f) * Gaussian(0.0484f * 1.414f, r)
           + new Color(0.118f, 0.198f, 0.0f) * Gaussian(0.1870f * 1.414f, r)
           + new Color(0.113f, 0.007f, 0.007f) * Gaussian(0.5670f * 1.414f, r)
           + new Color(0.358f, 0.004f, 0.0f) * Gaussian(1.9900f * 1.414f, r)
           + new Color(0.078f, 0.000f, 0.0f) * Gaussian(7.4100f * 1.414f, r);
    }
    Color integrateDiffuseScatteringOnRing(float cosTheta, float skinRadius)
    {

        float theta = Mathf.Acos(cosTheta);
        Color totalfenmu = Color.black;
        Color totalfenzi = Color.black;
        for (float t = -Mathf.PI / 2f; t < Mathf.PI / 2f; t = t + Mathf.PI / ins)
        {
            float sampleAngle = t + theta;
            float diffuse = Mathf.Cos(sampleAngle);
            if (diffuse <= 0)
                diffuse = 0;
            float sampleDist = Mathf.Abs(2.0f * skinRadius * Mathf.Sin(t * 0.5f));
            Color fenmu;
            if (sampleDist > 7.97f)
            {
                fenmu = Color.black;
            }
            else
            {
                fenmu = Scatter(sampleDist);
            }
            //分子积分，fx=NdL，t为散射影响的角度
            //2*fy*Mathf.Sin(t*0.5f)本来需要求绝对值，但Scatter是一个x轴对称函数，可以不求
            Color fenzi = diffuse * fenmu;
            totalfenmu += fenmu;
            totalfenzi += fenzi;
        }
        if (totalfenmu.r == 0 || totalfenmu.g == 0 || totalfenmu.b == 0)
        {
            float orginDiffuse = Mathf.Cos(theta);
            return new Color(orginDiffuse, orginDiffuse, orginDiffuse);
        }
        return new Color(Mathf.Pow(totalfenzi.r / totalfenmu.r, 1 / enhance), Mathf.Pow(totalfenzi.g / totalfenmu.g, 1 / enhance), Mathf.Pow(totalfenzi.b / totalfenmu.b, 1 / enhance));
        //Color res=new Color(totalfenzi.r / totalfenmu.r,totalfenzi.g / totalfenmu.g,totalfenzi.b / totalfenmu.b);
        //return res;
    }

    float integrateSzirmayKalosSpecular(float ndoth, float m)
    {
        float alpha = Mathf.Acos(ndoth);
        float ta = Mathf.Tan(alpha);
        float val = 1.0f / (m * m * Mathf.Pow(ndoth, 4.0f)) * Mathf.Exp(-(ta * ta) / (m * m));
        return val;

    }
    #endregion

    static int size;
    static float sizefloat;
    static Texture2D ScatteringMap;
    static Texture2D DiffuseScatteringOnRing;
    static Texture2D SzirmayKalosSpecular;
    [MenuItem("Tools/SSS材质生成工具")]
    public static void Open()
    {
        var wnd = GetWindow<SSSTextureTool>();
        wnd.Show();


    }

    private void OnEnable()
    {
        if (ScatteringMap == null)
        {
            DestroyImmediate(ScatteringMap);
            canSave = false;
            ScatteringMap = new Texture2D(size, size, TextureFormat.RGB24, false, true);
        }
        if (DiffuseScatteringOnRing == null)
        {
            DestroyImmediate(DiffuseScatteringOnRing);
            DiffuseScatteringOnRing = new Texture2D(256, 256, TextureFormat.RGB24, false, true);
        }
        if (SzirmayKalosSpecular == null)
        {
            DestroyImmediate(SzirmayKalosSpecular);
            SzirmayKalosSpecular = new Texture2D(size, size, TextureFormat.Alpha8, false, true);
        }
    }



    int selectedTabIndex = 0;
    static string[] contenttabs = new string[] { "参数填写", "预览扩散剖面", "散色LUT图", "高光LUT图" };
    private void OnGUI()
    {
        selectedTabIndex = GUILayout.Toolbar(selectedTabIndex, contenttabs, GUILayout.Height(40));
        switch (selectedTabIndex)
        {
            case 0: OnGUI_Param(); break;
            case 1: OnGUI_Profile(); break;
            case 2: OnGUI_CreateLUTs(); break;
            case 3: OnGUI_CreateSpecularLUTs(); break;
        }
    }
    private void OnGUI_Param()
    {
        EditorGUILayout.LabelField("开发中");
        EditorGUILayout.LabelField("即将包含的功能：另一套拟合函数的选择、多种材质的扩散剖面参数、自定义参数的序列化");
    }

    float offset;
    float offsetnew;
    float range;
    float rangenew;
    private void OnGUI_Profile()
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("亮度", GUILayout.Width(60));
        offsetnew = EditorGUILayout.Slider(offset, 0f, 2f);
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("缩放:", GUILayout.Width(60));
        rangenew = EditorGUILayout.Slider(range, 1f, 3f);
        EditorGUILayout.EndHorizontal();

        if (offsetnew != offset || rangenew != range)
        {
            range = rangenew;
            offset = offsetnew;
            button_SSSRing();
        }
        EditorGUILayout.Space();
        //EditorGUILayout.ObjectField(DiffuseScatteringOnRing, typeof(Texture2D), false, GUILayout.Width(400), GUILayout.Height(400));

        EditorGUI.DrawPreviewTexture(new Rect(0, 80, 384, 384), DiffuseScatteringOnRing);

    }

    bool canSave = false;
    float ins;
    float maxRadius;
    float enhance;
    int selectedresolution = 0;
    int newSelectedresolution = 0;
    static string[] resolutiontabs = new string[] { "128x128", "256x256", "512x512" };
    private void OnGUI_CreateLUTs()
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("1/r的值域", "值域越小越精确；越大适用范围越大，建议根据模型最小曲率决定范围", GUILayout.Width(80));
        maxRadius = EditorGUILayout.Slider(maxRadius, 0.25f, 1.5f);
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("迭代数", "迭代数越小烘焙越快；越大越锯齿越少", GUILayout.Width(80));
        ins = EditorGUILayout.Slider(ins, 30f, 1000f);
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("效果增强", "越快越鲜艳", GUILayout.Width(80));
        enhance = EditorGUILayout.Slider(enhance, 1f, 5f);
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("贴图分辨率", "分辨率越大越慢", GUILayout.Width(80));
        newSelectedresolution = GUILayout.Toolbar(selectedresolution, resolutiontabs, GUILayout.Height(20));
        switch (newSelectedresolution)
        {
            case 0:
                size = 128;
                sizefloat = size;
                break;
            case 1:
                size = 256;
                sizefloat = size; break;
            case 2:
                size = 512;
                sizefloat = size; break;
        }
        if (ScatteringMap.width == 0 || newSelectedresolution != selectedresolution)
        {
            selectedresolution = newSelectedresolution;
            ScatteringMap.Resize(size, size);
            canSave = false;
        }
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("生成"))
        {
            button_SSSTexture();
        }
        if (GUILayout.Button("生成并保存"))
        {
            button_SSSTexture();
            button_save(ref ScatteringMap, "human_skin");
        }
        EditorGUILayout.EndHorizontal();
        GUILayout.Space(sizefloat + 20f);
        if (!canSave)
        {
            GUI.color = Color.gray;
        }
        if (GUILayout.Button("保存到本地"))
        {
            if (canSave)
                button_save(ref ScatteringMap, "human_skin");
        }
        GUI.color = Color.white;

        EditorGUI.DrawPreviewTexture(new Rect(0, 160, size, size), ScatteringMap);

    }
    private void OnGUI_CreateSpecularLUTs()
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("贴图分辨率", "分辨率越大越慢", GUILayout.Width(80));
        newSelectedresolution = GUILayout.Toolbar(selectedresolution, resolutiontabs, GUILayout.Height(20));
        switch (newSelectedresolution)
        {
            case 0:
                size = 128;
                sizefloat = size;
                break;
            case 1:
                size = 256;
                sizefloat = size; break;
            case 2:
                size = 512;
                sizefloat = size; break;
        }
        if (SzirmayKalosSpecular.width == 0 || newSelectedresolution != selectedresolution)
        {
            selectedresolution = newSelectedresolution;
            SzirmayKalosSpecular.Resize(size, size);
            canSave = false;
        }
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("生成"))
        {
            button_SpecularTexture();
        }
        if (GUILayout.Button("生成并保存"))
        {
            button_SpecularTexture();
            button_save(ref SzirmayKalosSpecular, "Beckmann");
        }
        EditorGUILayout.EndHorizontal();
        GUILayout.Space(sizefloat + 20f);
        if (!canSave)
        {
            GUI.color = Color.gray;
        }
        if (GUILayout.Button("保存到本地"))
        {
            if (canSave)
                button_save(ref SzirmayKalosSpecular, "Beckmann");
        }
        GUI.color = Color.white;

        EditorGUI.DrawPreviewTexture(new Rect(0, 100, size, size), SzirmayKalosSpecular);

    }

    void button_save(ref Texture2D tex, string name)
    {

        // Encode texture into PNG
        byte[] bytes = tex.EncodeToPNG();
        File.WriteAllBytes(Application.dataPath + string.Format("/SSS_Master/TexOutput/" + name + ".png"), bytes);
        EditorUtility.DisplayDialog("保存成功", "纹理已经保存至assets/SSS_Master/TexOutput/" + name + ".png", "确认");


    }
    void button_SSSRing()
    {

        for (int y = 0; y < 256; y++)
        {
            for (int x = 0; x < 256; x++)
            {
                float xx = x;
                float yy = y;
                float radius = Mathf.Sqrt((256 / 2.00f - xx) * (256 / 2.00f - xx) + (256 / 2.00f - yy) * (256 / 2.00f - yy));
                Color res = Scatter(radius / 100f * range);
                DiffuseScatteringOnRing.SetPixel(x, y, res / offset);
            }
        }
        DiffuseScatteringOnRing.Apply();
    }

    void button_SSSTexture()
    {
        bool IsGoOnWorking = false;

        for (int y = 0; y < ScatteringMap.height; y++)
        {
            float yy = y;
            IsGoOnWorking = EditorUtility.DisplayCancelableProgressBar("烘焙LUT贴图中", "请稍后", y / (float)ScatteringMap.height);
            if (IsGoOnWorking)
            {
                ScatteringMap.Apply();
                EditorUtility.ClearProgressBar();
                return;
            }
            for (int x = 0; x < ScatteringMap.width; x++)
            {
                float skinRadius;
                if (y == 0)
                    skinRadius = 999f;
                else
                    skinRadius = 1.0f / (yy / sizefloat) / maxRadius;
                float cosTheta = x / sizefloat * 2f - 1f;
                Color color = integrateDiffuseScatteringOnRing(cosTheta, skinRadius);
                ScatteringMap.SetPixel(x, y, color);

            }



        }
        EditorUtility.ClearProgressBar();
        ScatteringMap.Apply();
        canSave = true;
    }
    void button_SpecularTexture()
    {

        for (int y = 0; y < SzirmayKalosSpecular.height * 2; y = y + 2)
        {
            for (int x = 0; x < SzirmayKalosSpecular.width * 2; x = x + 2)
            {
                //超采样
                float rough = y / sizefloat / 2f;
                float cosTheta = x / sizefloat / 2f;
                float res1 = 0.5f * Mathf.Pow(integrateSzirmayKalosSpecular(cosTheta, rough), 0.1f);
                float res2 = 0.5f * Mathf.Pow(integrateSzirmayKalosSpecular(cosTheta + 1 / sizefloat / 2f, rough), 0.1f);
                float res3 = 0.5f * Mathf.Pow(integrateSzirmayKalosSpecular(cosTheta, rough + 1 / sizefloat / 2f), 0.1f);
                float res4 = 0.5f * Mathf.Pow(integrateSzirmayKalosSpecular(cosTheta + 1 / sizefloat / 2f, rough + 1 / sizefloat / 2f), 0.1f);
                float res = (res1 + res3 + res2 + res4) / 4f;
                Color color = new Color(0f, 0f, 0f, res);
                SzirmayKalosSpecular.SetPixel(x / 2, y / 2, color);
            }
        }
        SzirmayKalosSpecular.Apply();
        canSave = true;
        Debug.Log(SzirmayKalosSpecular.width);
    }
   

}
#endif