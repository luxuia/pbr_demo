using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Profiler : MonoBehaviour {

    public int SampleCount = 100;
	// Use this for initialization
	void Start () {
        last = System.DateTime.Now;
    }

    System.DateTime last;

    double elapseTime = 0;
    

    public Renderer render;
	
	// Update is called once per frame
	void Update () {
        //render.material.SetInt("_ITER_COUNT", SampleCount);
        /*
        var before = System.DateTime.Now;
        for (var i = 0; i < SampleCount; ++i) {
            Camera.main.Render();
        }
        var delta = (System.DateTime.Now - before).TotalMilliseconds;
        elapseTime = delta / SampleCount;
        */
        elapseTime = (System.DateTime.Now - last).TotalMilliseconds;
        last = System.DateTime.Now;
        }

    private void OnGUI() {
        GUI.Label(new Rect(10, 10, 500, 20), string.Format("Elapse For Render({0}) : {1}", SampleCount, elapseTime.ToString()));
        SampleCount = (int)GUI.HorizontalSlider(new Rect(10, 50, 200, 20), SampleCount, 10, 2000);
    }
}
