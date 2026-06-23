using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class BattlePassScrollIndicator : MonoBehaviour
{
    [System.Serializable]
    public class SideLabel
    {
        public GameObject root;
        public TMP_Text levelText;
        public Image itemIcon;
        public TMP_Text itemText;
        public Button button;
    }

    public LevelProgressBar progressBar;
    public ScrollRect scrollRect;
    public RectTransform viewport;
    public RectTransform content;

    public SideLabel leftLabel;
    public SideLabel rightLabel;

    public string levelFormat = "LEVEL {0}";
    public float scrollDuration = 0.35f;

    [Range(0f, 0.5f)] public float leftMargin = 0.15f;   // fraction of viewport width
    [Range(0f, 0.5f)] public float rightMargin = 0.15f;

    readonly List<int> levels = new List<int>();
    readonly List<RectTransform> markers = new List<RectTransform>();
    readonly List<BattlePassNode> allNodes = new List<BattlePassNode>();
    readonly Vector3[] corners = new Vector3[4];

    Coroutine scrollRoutine;
    RectTransform rightTarget;
    int shownLevel = int.MinValue;
    int lastLevel = int.MinValue;

    enum View { Visible, OffLeft, OffRight }

    void Awake()
    {
        if (scrollRect != null)
        {
            if (viewport == null) viewport = scrollRect.viewport;
            if (content == null) content = scrollRect.content;
        }

        if (leftLabel.button != null) leftLabel.button.onClick.AddListener(GoToNextLevel);
        if (rightLabel.button != null) rightLabel.button.onClick.AddListener(() => ScrollTo(rightTarget));

        if (leftLabel.itemIcon != null) leftLabel.itemIcon.enabled = false;
    }

    void OnEnable()
    {
        if (scrollRect != null) scrollRect.onValueChanged.AddListener(OnScroll);
    }

    void OnDisable()
    {
        if (scrollRect != null) scrollRect.onValueChanged.RemoveListener(OnScroll);
    }

    void Start()
    {
        CollectNodes();
        UpdateLabels();
    }

    void Update()
    {
        if (CurrentLevel != lastLevel) UpdateLabels();
    }

    void OnScroll(Vector2 _)
    {
        UpdateLabels();
    }

    public void CollectNodes()
    {
        levels.Clear();
        markers.Clear();
        allNodes.Clear();
        if (content == null) return;

        allNodes.AddRange(content.GetComponentsInChildren<BattlePassNode>(true));
        allNodes.Sort((a, b) => a.Rect.position.x.CompareTo(b.Rect.position.x));

        var byLevel = new SortedDictionary<int, RectTransform>();
        foreach (var node in allNodes)
            if (node.levelDriven && node.isPremium && !byLevel.ContainsKey(node.level))
                byLevel[node.level] = node.Rect;

        foreach (var kv in byLevel)
        {
            levels.Add(kv.Key);
            markers.Add(kv.Value);
        }
    }

    void UpdateLabels()
    {
        lastLevel = CurrentLevel;
        UpdateLeft();
        UpdateRight();
    }

    void UpdateLeft()
    {
        int next = NextLevel();
        RectTransform marker = next != CurrentLevel ? MarkerForLevel(next) : null;
        bool show = marker != null && GetView(marker) == View.OffLeft;

        SetActive(leftLabel.root, show);

        if (show && next != shownLevel)
        {
            if (leftLabel.levelText != null) leftLabel.levelText.text = string.Format(levelFormat, next);
            shownLevel = next;
        }
    }

    void GoToNextLevel()
    {
        RectTransform marker = MarkerForLevel(NextLevel());
        if (marker != null) ScrollTo(marker);
    }

    void UpdateRight()
    {
        BattlePassNode valuable = UpcomingValuable();
        bool show = valuable != null;

        SetActive(rightLabel.root, show);

        if (show)
        {
            rightTarget = valuable.Rect;
            if (rightLabel.itemIcon != null)
            {
                rightLabel.itemIcon.sprite = valuable.Icon;
                rightLabel.itemIcon.enabled = true;
            }
            if (rightLabel.itemText != null) rightLabel.itemText.text = valuable.DisplayName;
        }
    }

    BattlePassNode UpcomingValuable()
    {
        for (int i = 0; i < allNodes.Count; i++)
            if (allNodes[i].isValuable && GetView(allNodes[i].Rect) == View.OffRight)
                return allNodes[i];
        return null;
    }

    int CurrentLevel => progressBar != null ? progressBar.CurrentLevel : 0;

    int NextLevel()
    {
        int cur = CurrentLevel;
        for (int i = 0; i < levels.Count; i++)
            if (levels[i] > cur) return levels[i];
        return cur;
    }

    RectTransform MarkerForLevel(int level)
    {
        int idx = levels.IndexOf(level);
        return idx >= 0 ? markers[idx] : null;
    }

    View GetView(RectTransform rt)
    {
        if (rt == null || viewport == null) return View.Visible;

        rt.GetWorldCorners(corners);
        float center = (corners[0].x + corners[3].x) * 0.5f;

        viewport.GetWorldCorners(corners);
        float viewLeft = corners[0].x;
        float viewRight = corners[3].x;
        float width = viewRight - viewLeft;

        if (center < viewLeft + leftMargin * width) return View.OffLeft;
        if (center > viewRight - rightMargin * width) return View.OffRight;
        return View.Visible;
    }

    static void SetActive(GameObject go, bool on)
    {
        if (go != null && go.activeSelf != on) go.SetActive(on);
    }

    public void ScrollTo(RectTransform target)
    {
        if (target == null || scrollRect == null) return;
        if (scrollRoutine != null) StopCoroutine(scrollRoutine);
        scrollRoutine = StartCoroutine(ScrollRoutine(target));
    }

    IEnumerator ScrollRoutine(RectTransform target)
    {
        float from = scrollRect.horizontalNormalizedPosition;
        float to = NormalizedPositionFor(target);

        float t = 0f;
        while (t < scrollDuration && scrollDuration > 0f)
        {
            t += Time.unscaledDeltaTime;
            float k = Mathf.SmoothStep(0f, 1f, t / scrollDuration);
            scrollRect.horizontalNormalizedPosition = Mathf.Lerp(from, to, k);
            yield return null;
        }

        scrollRect.horizontalNormalizedPosition = to;
        scrollRoutine = null;
    }

    float NormalizedPositionFor(RectTransform target)
    {
        content.GetWorldCorners(corners);
        float contentLeft = corners[0].x;
        float contentWidth = corners[3].x - corners[0].x;

        viewport.GetWorldCorners(corners);
        float viewWidth = corners[3].x - corners[0].x;

        float scrollable = contentWidth - viewWidth;
        if (scrollable <= 0.0001f) return 0f;

        target.GetWorldCorners(corners);
        float itemCenter = (corners[0].x + corners[3].x) * 0.5f;
        float fromLeftCentered = (itemCenter - contentLeft) - viewWidth * 0.5f;
        return Mathf.Clamp01(fromLeftCentered / scrollable);
    }
}
