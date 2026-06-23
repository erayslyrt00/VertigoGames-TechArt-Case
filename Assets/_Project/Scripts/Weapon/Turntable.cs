using UnityEngine;

namespace VertigoDemo.Weapon
{
    public class Turntable : MonoBehaviour
    {
        [SerializeField] private float _speed = 20f;
        [SerializeField] private Vector3 _axis = Vector3.up;

        private Vector3 _pivot;

        void Start()
        {
            _pivot = transform.position;

            bool found = false;
            Bounds bounds = default;
            foreach (var r in GetComponentsInChildren<Renderer>())
            {
                if (r is ParticleSystemRenderer) continue;
                if (!found) { bounds = r.bounds; found = true; }
                else bounds.Encapsulate(r.bounds);
            }

            if (found) _pivot = bounds.center;
        }

        void Update()
        {
            transform.RotateAround(_pivot, _axis, _speed * Time.deltaTime);
        }
    }
}
