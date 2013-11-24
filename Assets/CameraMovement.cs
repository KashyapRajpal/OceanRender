using UnityEngine;
using System.Collections;

public class CameraMovement : MonoBehaviour {

	// Use this for initialization
	void Start () {
	}

	void AdjustReflectionCamera(){
		
		GameObject mainCamera;
		mainCamera = GameObject.Find("MainCamera");
		GameObject reflectionCamera;
		reflectionCamera = GameObject.Find("ReflectionCamera");
		
		//Copy Position
		Vector3 transformMat = mainCamera.transform.position;
		transformMat.y = -transformMat.y;
		reflectionCamera.transform.position = transformMat;
		
		//Copy Rotation
		Quaternion rotMat = mainCamera.transform.localRotation;
		reflectionCamera.transform.localRotation = rotMat;
		
		rotMat = mainCamera.transform.rotation;
		reflectionCamera.transform.rotation = rotMat;

	}
	// Update is called once per frame
	void Update () {
		AdjustReflectionCamera();
	}
}
