using UnityEngine;
using UnityEngine.InputSystem;

namespace VertigoDemo.Weapon
{
    public class Turntable : MonoBehaviour
    {
        [SerializeField] private float _speed = 20f;
        [SerializeField] private Vector3 _axis = Vector3.up;
        [SerializeField] private float _dragSpeed = 0.2f;
        [SerializeField] private float _damping = 3f;

        private Vector3 _pivot;
        private float _angularVel;
        private float _autoSign = 1f;

        void Start()
        {
            _pivot = transform.position;
            _angularVel = _speed;

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
            float dt = Time.deltaTime;
            var pointer = Pointer.current;

            if (pointer != null && pointer.press.isPressed)
            {
                float dx = pointer.delta.ReadValue().x;
                if (dx != 0f)
                {
                    float angle = -dx * _dragSpeed;
                    transform.RotateAround(_pivot, _axis, angle);
                    _angularVel = dt > 0f ? angle / dt : 0f;
                    _autoSign = Mathf.Sign(angle);
                    return;
                }
            }

            float target = _speed * _autoSign;
            _angularVel = Mathf.Lerp(_angularVel, target, 1f - Mathf.Exp(-_damping * dt));
            transform.RotateAround(_pivot, _axis, _angularVel * dt);
        }
    }
}
