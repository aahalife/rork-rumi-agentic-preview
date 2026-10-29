import Foundation
import WebKit

struct WorksObservation: Codable {
    struct Element: Codable {
        let ref: Int
        let tag: String
        let name: String
        let type: String
        let value: String
        let href: String
        let sensitive: Bool
        let x: Double
        let y: Double
    }
    let document: String
    let revision: Int
    let url: String
    let title: String
    let text: String
    let elements: [Element]
    let width: Double
    let height: Double
    let scrollX: Double
    let scrollY: Double
    let blockedFrames: Int
    let sensitive: Bool
    func json() throws -> String { String(decoding: try JSONEncoder().encode(self), as: UTF8.self) }
}
struct WorksAction: Codable {
    let kind: String
    let ref: Int?
    let text: String?
    let url: String?
    let direction: String?
    let x: Double?
    let y: Double?
    let summary: String
    var needsApproval: Bool { ["click", "type_text", "select_option", "navigate", "visual_click"].contains(kind) }
}

/// Runs in a named isolated world: sites share DOM, not these references or message handlers.
@MainActor enum WorksBridge {
    static let world = WKContentWorld.world(name: "RumiAgent")
    static let script = #"""
    (() => {
      if (window.rumiBridge) return;
      const doc = crypto.randomUUID();
      let revision = 0, counter = 0, masking = false;
      const refs = new Map(), ids = new WeakMap();
      const clean = s => String(s || '').replace(/\s+/g, ' ').trim();
      const visible = e => { const r=e.getBoundingClientRect(), s=getComputedStyle(e); return r.width>0 && r.height>0 && s.visibility!=='hidden' && s.display!=='none'; };
      const sensitive = e => {
        const label = [e.type,e.name,e.id,e.autocomplete,e.getAttribute('aria-label')].join(' ');
        return /password|passcode|username|login|one.time|otp|verification|secret|token|credit|card.number|cc-|cvc|cvv|ssn|social.security/i.test(label)
          || e.type === 'email' || !!e.closest('form')?.querySelector('input[type=password]');
      };
      const notify = type => { try { window.webkit.messageHandlers.rumiBrowser.postMessage({type}); } catch {} };
      const changed = () => { if (!masking) { revision++; notify('changed'); } };
      const observer = new MutationObserver(changed);
      document.addEventListener('scroll',changed,true);
      const watch = () => observer.observe(document.documentElement, {subtree:true,childList:true,characterData:true,attributes:true});
      watch();
      ['pointerdown','touchstart','keydown','input','change'].forEach(type => document.addEventListener(type,e=> {
        if (e.isTrusted) { revision++; notify('takeover'); }
      },true));
      function snapshot() {
        if (observer.takeRecords().length) changed();
        const elements=[]; let budget=23500;
        for (const [id,e] of refs) if(!e.isConnected) refs.delete(id);
        for (const e of document.querySelectorAll('a[href],button,input,textarea,select,[role=button],[role=link],[contenteditable=true]')) {
          if (!visible(e) || e.type==='hidden') continue;
          if (!ids.has(e)) { ids.set(e,++counter); refs.set(counter,e); }
          const r=e.getBoundingClientRect(), secret=sensitive(e);
          const label=e.getAttribute('aria-label') || e.labels?.[0]?.innerText || e.getAttribute('placeholder') || e.innerText || e.getAttribute('title') || e.name || '';
          refs.set(ids.get(e),e);
          const entry={ref:ids.get(e),tag:e.tagName.toLowerCase(),name:secret?'Private field — user only':clean(label).slice(0,250),type:e.type||'',value:secret?'[private]':String(e.value ?? (e.isContentEditable?e.textContent:'')).slice(0,3000),href:e.tagName==='A' ? (()=>{ try {const u=new URL(e.href);u.hash='';return u.origin+u.pathname;}catch{return '';}})():'',sensitive:secret,x:r.x+r.width/2,y:r.y+r.height/2};
          const size=JSON.stringify(entry).length;
          if(size<=budget) { elements.push(entry);budget-=size; }
          if (elements.length>=180 || budget<300) break;
        }
        const clone=document.body.cloneNode(true);
        clone.querySelectorAll('script,style,noscript,input,textarea,select,[contenteditable],iframe').forEach(e=>e.remove());
        const u=new URL(location.href); u.hash=''; u.search='';
        return {document:doc,revision,url:u.href,title:document.title.slice(0,300),text:clean(clone.innerText||clone.textContent).slice(0,18000),elements,width:innerWidth,height:innerHeight,scrollX,scrollY,blockedFrames:document.querySelectorAll('iframe').length,sensitive:elements.some(e=>e.sensitive)};
      }
      function target(action) {
        if (action.kind==='visual_click') {
          if (!Number.isFinite(action.x)||!Number.isFinite(action.y)||action.x<0||action.y<0||action.x>=innerWidth||action.y>=innerHeight) throw Error('Point is outside the current page.');
          const e=document.elementFromPoint(action.x,action.y);
          if (!e || e.closest('iframe') || e.tagName==='IFRAME') throw Error('Use this part of the page yourself.');
          return e.closest('a,button,input,textarea,select,[role=button],[role=link]') || e;
        }
        const e=refs.get(action.ref);
        if(!e || !e.isConnected || !visible(e)) throw Error('That element is no longer available.');
        const r=e.getBoundingClientRect(),cx=r.x+r.width/2,cy=r.y+r.height/2;
        if(cx<0||cy<0||cx>=innerWidth||cy>=innerHeight) throw Error('Scroll this control into view first.');
        const hit=document.elementFromPoint(cx,cy);
        if(!hit || !(hit===e||e.contains(hit))) throw Error('Another part of the page is covering this control.');
        return e;
      }
      function describe(action) {
        const e=target(action);
        if(sensitive(e) || e.closest('form')?.querySelector('input[type=password]')) throw Error('Sign-in and private fields are for you to use directly.');
        const form=e.closest('form');
        if(form && Array.from(form.querySelectorAll('input,textarea,select')).some(f=>sensitive(f))) throw Error('Use this form yourself: it contains private fields that cannot be included in an exact-action review.');
        return {label:clean(e.getAttribute('aria-label')||e.innerText||e.labels?.[0]?.innerText||e.name||e.tagName).slice(0,500),
          form:form ? Array.from(form.querySelectorAll('input,textarea,select,[contenteditable]')).filter(visible).map(f=>({name:clean(f.labels?.[0]?.innerText||f.name||f.id),value:sensitive(f)?'[private]':String(f.value??f.textContent).slice(0,6000)})) : [],
          destination:e.tagName==='A'?e.href:''};
      }
      const stable = value => JSON.stringify(value, (_,v) => v && typeof v==='object' && !Array.isArray(v) ? Object.keys(v).sort().reduce((a,k)=>(a[k]=v[k],a),{}) : v);
      function perform(action, expected) {
        const fresh=snapshot();
        if(fresh.document!==expected.document || fresh.revision!==expected.revision || stable(fresh.elements)!==stable(expected.elements) || fresh.text!==expected.text || fresh.url!==expected.url || fresh.scrollX!==expected.scrollX || fresh.scrollY!==expected.scrollY || fresh.width!==expected.width || fresh.height!==expected.height) throw Error('The page changed. Review a fresh proposal.');
        if(action.kind==='navigate') { const u=new URL(action.url); if(u.protocol!=='https:'||u.username||u.password)throw Error('Unsupported address.'); location.assign(u.href);return 'Navigation requested. Check the destination.'; }
        if(action.kind==='scroll') { window.scrollBy({top:(action.direction==='up'?-0.75:0.75)*innerHeight,behavior:'instant'}); return 'Scrolled'; }
        const e=target(action);
        describe(action);
        if(e.disabled) throw Error('This control is disabled.');
        if(action.kind==='click'||action.kind==='visual_click') { e.click(); return 'Click dispatched. Check the updated page for the outcome.'; }
        if(action.kind==='type_text') {
          if(!['INPUT','TEXTAREA'].includes(e.tagName)&&!e.isContentEditable) throw Error('Not an editable field.');
          if(e.tagName==='INPUT' && !['text','search','url','tel','number',''].includes(e.type)) throw Error('Use this field yourself.');
          e.focus();
          if(e.isContentEditable) e.textContent=action.text||'';
          else {const p=e.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;Object.getOwnPropertyDescriptor(p,'value').set.call(e,action.text||'');}
          e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));
          return 'Field updated; not submitted.';
        }
        if(action.kind==='select_option') {
          if(e.tagName!=='SELECT') throw Error('Not a selection field.');
          const option=Array.from(e.options).find(o=>o.value===action.text||clean(o.text)===action.text);
          if(!option) throw Error('That option is not available.');
          Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'value').set.call(e,option.value);
          e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return 'Selection updated.';
        }
        throw Error('Unsupported browser action.');
      }
      let overlays=[];
      function mask(on) {
        if(on) {
          masking=true; observer.disconnect();
          document.querySelectorAll('input,textarea,select,[contenteditable],iframe').forEach(e=>{
            if(!visible(e))return;const r=e.getBoundingClientRect(),o=document.createElement('div');
            Object.assign(o.style,{position:'fixed',left:r.left+'px',top:r.top+'px',width:r.width+'px',height:r.height+'px',background:'#dbe5df',zIndex:'2147483647',pointerEvents:'none'});
            document.documentElement.appendChild(o);overlays.push(o);
          });
        } else { overlays.forEach(e=>e.remove());overlays=[];masking=false;watch(); }
      }
      window.rumiBridge={snapshot,describe,perform,mask};
    })();
    """#
    static func call(_ web: WKWebView, method: String, arguments: [String: Any] = [:]) async throws -> String {
        let source: String
        switch method {
        case "snapshot": source = "return JSON.stringify(window.rumiBridge.snapshot());"
        case "describe": source = "return JSON.stringify(window.rumiBridge.describe(action));"
        case "perform": source = "return JSON.stringify(window.rumiBridge.perform(action,expected));"
        case "mask": source = "window.rumiBridge.mask(on); return '{}';"
        default: throw CompanionError(message: "Unsupported browser instruction.")
        }
        let value = try await web.callAsyncJavaScript(source, arguments: arguments, in: nil, contentWorld: world)
        guard let json = value as? String else { throw CompanionError(message: "This page cannot be read yet. Wait for it to finish loading.") }
        return json
    }
    static func dictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        guard let data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any] else { throw CompanionError(message: "The page could not be read.") }
        return data
    }
}
