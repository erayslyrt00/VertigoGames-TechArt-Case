using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class LevelProgressBar : MonoBehaviour
{
    public Image fill;                // Progress_Fill (Filled, Horizontal, Left)
    public RectTransform bar;         // Progress_Bg
    public RectTransform buyButton;
    public Button buyButtonComponent;
    public RectTransform[] followers; // gradients that ride with the button
    public RectTransform content;     // scroll content with the level columns

    public int currentLevel = 0;      // 0 = before level 1
    public float buttonSmoothTime = 0.3f;
    public float followerLag = 0.35f;

    public int CurrentLevel => currentLevel;
    public bool IsBuying => anim != null;

    Coroutine anim;
    float[] followerOffsets;
    float[] followerVel;
    readonly List<int> levels = new List<int>();
    readonly List<RectTransform> markers = new List<RectTransform>();
    readonly List<BattlePassNode> stateNodes = new List<BattlePassNode>();
    readonly Vector3[] corners = new Vector3[4];

    void Awake()
    {
        if (buyButtonComponent != null) buyButtonComponent.onClick.AddListener(Buy);
    }

    void Start()
    {
        CollectNodes();
        CacheFollowerOffsets();
        RefreshStates();

        if (content != null)
        {
            Canvas.ForceUpdateCanvases();
            LayoutRebuilder.ForceRebuildLayoutImmediate(content);
        }

        if (fill != null && bar != null && buyButton != null)
        {
            if (IsLastLevel(currentLevel))
            {
                fill.fillAmount = 1f;
                SyncButtonToFill();
                HideButton();
            }
            else
            {
                fill.fillAmount = GapFraction(currentLevel);
                SyncButtonToFill();
                SnapFollowers();
            }
        }
    }

    // Markers come only from premium, level-driven nodes (intro + free excluded).
    public void CollectNodes()
    {
        levels.Clear();
        markers.Clear();
        stateNodes.Clear();
        if (content == null) return;

        stateNodes.AddRange(content.GetComponentsInChildren<BattlePassNode>(true));

        var byLevel = new SortedDictionary<int, RectTransform>();
        foreach (var node in stateNodes)
            if (node.levelDriven && node.isPremium && !byLevel.ContainsKey(node.level))
                byLevel[node.level] = node.Rect;

        foreach (var kv in byLevel)
        {
            levels.Add(kv.Key);
            markers.Add(kv.Value);
        }
    }

    void RefreshStates()
    {
        for (int i = 0; i < stateNodes.Count; i++)
            if (stateNodes[i] != null) stateNodes[i].RefreshForLevel(currentLevel);
    }

    public void Buy()
    {
        if (anim != null) return;

        if (fill == null || bar == null || buyButton == null || levels.Count == 0)
        {
            Debug.LogWarning("LevelProgressBar: fill / bar / buyButton / content not assigned.", this);
            return;
        }

        int next = NextLevel(currentLevel);
        if (next == currentLevel) return; // already at the last level

        anim = StartCoroutine(BuyRoutine(next));
    }

    IEnumerator BuyRoutine(int targetLevel)
    {
        bool last = IsLastLevel(targetLevel);
        float target = last ? 1f : GapFraction(targetLevel);

        float vel = 0f;
        while (Mathf.Abs(fill.fillAmount - target) > 0.0005f)
        {
            fill.fillAmount = Mathf.SmoothDamp(fill.fillAmount, target, ref vel, buttonSmoothTime, Mathf.Infinity, Time.unscaledDeltaTime);
            SyncButtonToFill();
            yield return null;
        }
        fill.fillAmount = target;
        SyncButtonToFill();

        currentLevel = targetLevel;
        RefreshStates();

        if (last) HideButton();
        anim = null;
    }

    int NextLevel(int level)
    {
        for (int i = 0; i < levels.Count; i++)
            if (levels[i] > level) return levels[i];
        return level;
    }

    bool IsLastLevel(int level)
    {
        return levels.Count > 0 && NextLevel(level) == level && level >= levels[levels.Count - 1];
    }

    void HideButton()
    {
        if (buyButton != null) buyButton.gameObject.SetActive(false);
        if (followers != null)
            for (int i = 0; i < followers.Length; i++)
                if (followers[i] != null) followers[i].gameObject.SetActive(false);
    }

    float GapFraction(int level)
    {
        float lower = FractionForLevel(level);
        float upper = FractionForLevel(level + 1);
        return Mathf.Clamp01((lower + upper) * 0.5f);
    }

    // levels below the first marker are extrapolated from the first two so level 0 sits just left of level 1
    float FractionForLevel(int level)
    {
        for (int i = 0; i < levels.Count; i++)
            if (levels[i] == level) return FractionForMarker(markers[i]);

        if (levels.Count >= 2)
        {
            float f0 = FractionForMarker(markers[0]);
            float f1 = FractionForMarker(markers[1]);
            float spacing = (f1 - f0) / Mathf.Max(1, levels[1] - levels[0]);
            return f0 + (level - levels[0]) * spacing;
        }
        if (levels.Count == 1) return FractionForMarker(markers[0]);
        return 0f;
    }

    float FractionForMarker(RectTransform marker)
    {
        bar.GetWorldCorners(corners);
        float left = corners[0].x;
        float right = corners[3].x;
        if (right - left <= 0.0001f) return 0f;

        marker.GetWorldCorners(corners);
        float markerX = (corners[0].x + corners[3].x) * 0.5f;
        return (markerX - left) / (right - left);
    }

    // world-space x so the button can live on a layer above the columns
    void SyncButtonToFill()
    {
        bar.GetWorldCorners(corners);
        float worldX = Mathf.Lerp(corners[0].x, corners[3].x, fill.fillAmount);

        Vector3 bp = buyButton.position;
        bp.x = worldX;
        buyButton.position = bp;
    }

    void LateUpdate()
    {
        if (followers == null || followerOffsets == null || buyButton == null) return;
        for (int i = 0; i < followers.Length; i++)
        {
            if (followers[i] == null || !followers[i].gameObject.activeInHierarchy) continue;
            float targetX = buyButton.position.x + followerOffsets[i];
            Vector3 fp = followers[i].position;
            fp.x = Mathf.SmoothDamp(fp.x, targetX, ref followerVel[i], followerLag, Mathf.Infinity, Time.unscaledDeltaTime);
            followers[i].position = fp;
        }
    }

    void SnapFollowers()
    {
        if (followers == null || followerOffsets == null || buyButton == null) return;
        for (int i = 0; i < followers.Length; i++)
        {
            if (followers[i] == null) continue;
            Vector3 fp = followers[i].position;
            fp.x = buyButton.position.x + followerOffsets[i];
            followers[i].position = fp;
            followerVel[i] = 0f;
        }
    }

    void CacheFollowerOffsets()
    {
        if (followers == null || buyButton == null) return;
        followerOffsets = new float[followers.Length];
        followerVel = new float[followers.Length];
        for (int i = 0; i < followers.Length; i++)
            if (followers[i] != null)
                followerOffsets[i] = followers[i].position.x - buyButton.position.x;
    }
}
