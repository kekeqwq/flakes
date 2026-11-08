"use strict";
const { Plugin } = require("obsidian");

module.exports = class BottomNavigation extends Plugin {
  onload() {
    this.moved = new Map();
    this.alive = true;
    const schedule = () => {
      if (!this.alive) return;
      cancelAnimationFrame(this.frame);
      this.frame = requestAnimationFrame(() => this.sync());
    };
    for (const event of ["active-leaf-change", "layout-change", "file-open"]) {
      this.registerEvent(this.app.workspace.on(event, schedule));
    }
    this.app.workspace.onLayoutReady(schedule);
    this.register(() => {
      this.alive = false;
      cancelAnimationFrame(this.frame);
      for (const nav of [...this.moved.keys()]) this.restore(nav);
    });
  }

  restore(nav) {
    const { parent, next } = this.moved.get(nav);
    parent.insertBefore(nav, next?.parentNode === parent ? next : null);
    nav.classList.remove("bottom-tab-navigation");
    this.moved.delete(nav);
  }

  sync() {
    const wanted = new Map();
    this.app.workspace.iterateAllLeaves((leaf) => {
      // Each split has its own selected tab, independent of keyboard focus.
      const tab = leaf.tabHeaderEl;
      if (!tab?.classList.contains("is-active")) return;
      const bar = tab.closest(".workspace-tab-header-container");
      if (!bar?.closest(".mod-root")) return;
      const header = leaf.view?.headerEl;
      if (!header) return;
      const existing = [...this.moved].find(([, origin]) =>
        header.contains(origin.parent),
      );
      const nav =
        header.querySelector(".view-header-nav-buttons") || existing?.[0];
      if (nav) wanted.set(nav, bar);
    });
    for (const nav of [...this.moved.keys()]) {
      if (!wanted.has(nav)) this.restore(nav);
    }
    for (const [nav, bar] of wanted) {
      if (!this.moved.has(nav)) {
        this.moved.set(nav, { parent: nav.parentNode, next: nav.nextSibling });
      }
      nav.classList.add("bottom-tab-navigation");
      if (nav.parentNode !== bar) bar.insertBefore(nav, bar.firstChild);
    }
  }
};
