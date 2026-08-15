// model-toggle — 浏览器端一键切换「本会话」模型按钮（DeepSeek-V4-Pro Max ↔ Flash Max）。
// 通过官方 wire API（sessions.models / sessions.selectModel）读写会话模型选择，
// 与输入框旁的官方模型选择器共享同一状态源，无需任何 host RPC。
window.__ModuleLoader__.load({
  id: 'model-toggle',
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
    let react = require('react');
    const PRO = 'deepseek-v4-pro';
    const FLASH = 'deepseek-v4-flash';
    const labelOf = (m) => m === PRO ? 'Pro Max' : (m === FLASH ? 'Flash Max' : String(m || '未知'));
    const inject = ['sessions', 'slots'];
    function Toggle(props) {
      const sessionId = props.sessionId;
      const sessions = props.sessions;
      const [sel, setSel] = react.useState(null);
      const [err, setErr] = react.useState(null);
      const [busy, setBusy] = react.useState(false);
      const [ok, setOk] = react.useState(false);
      react.useEffect(() => {
        let alive = true;
        if (sessionId === undefined || sessions === undefined) return;
        sessions.models({ sessionId }).then((r) => {
          if (!alive) return;
          if (r !== undefined && r.result !== undefined && r.result.ok) {
            setSel(r.result.value.current);
            setErr(null);
          } else {
            setErr('状态读取失败');
          }
        }).catch(() => {});
        return () => { alive = false };
      }, [sessionId, props.session, sessions]);
      const onClick = () => {
        if (busy || sel === null || sessions === undefined) return;
        setBusy(true);
        const target = sel.model === FLASH ? PRO : (sel.model === PRO ? FLASH : PRO);
        sessions.selectModel({ sessionId, provider: sel.provider, model: target, reasoningEffort: 'max' }).then((r) => {
          if (r !== undefined && r.result !== undefined && r.result.ok) {
            setSel(r.result.value.selected);
            setErr(null);
            setOk(true);
            setTimeout(() => setOk(false), 1500);
          } else {
            setErr('切换失败');
          }
        }).catch(() => setErr('切换请求失败')).then(() => setBusy(false));
      };
      const label = sel === null ? '…' : labelOf(sel.model);
      const other = sel !== null && sel.model === PRO ? 'Flash Max' : 'Pro Max';
      const title = sel === null ? '读取本会话模型…' : (err !== null ? err : '一键切换本会话模型：' + label + ' → ' + other);
      return react.createElement('button', {
        type: 'button',
        style: {
          display: 'inline-flex',
          alignItems: 'center',
          gap: '5px',
          padding: '4px 10px',
          borderRadius: '999px',
          border: '1px solid var(--dsw-alias-border-l1)',
          background: 'var(--dsw-alias-bg-layer-1)',
          color: err !== null ? 'var(--dsw-alias-state-error-primary)' : 'var(--dsw-alias-label-primary)',
          fontSize: '12px',
          lineHeight: '16px',
          cursor: 'pointer',
          whiteSpace: 'nowrap',
          userSelect: 'none',
          fontFamily: 'inherit',
        },
        title: title,
        disabled: busy || sel === null,
        onClick: onClick,
      }, ok ? '✓' : ('⚡ ' + label));
    }
    function apply(ctx) {
      ctx.inject(['sessions', 'slots'], (scope) => {
        const sessions = scope.sessions;
        scope.slots.inject('conversation.input.right', () => scope.slots.register(
          { name: 'conversation.input.right', id: 'model-toggle-button', label: () => '本会话模型一键切换' },
          (props) => react.createElement(Toggle, Object.assign({}, props, { sessions })),
        ));
      });
    }
    exports.apply = apply;
    exports.inject = inject;
    return module.exports;
  }
});
