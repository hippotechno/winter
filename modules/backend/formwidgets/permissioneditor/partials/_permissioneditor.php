<style>
    .perm-tools {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
    }
    .perm-tools .uk-input {
        width: 100%;
    }
    .perm-tools > .uk-flex-1 {
        min-width: 220px;
    }
    .permissioneditor.is-dirty .uk-select {
        border-color: #f59e0b;
    }
</style>

<div class="permissioneditor <?= $this->previewMode ? 'control-disabled' : '' ?>" <?= $field->getAttributes() ?>>
    <div class="perm-tools uk-margin-small uk-flex uk-flex-middle uk-flex-wrap">
        <div class="uk-flex-1 uk-margin-small-right">
            <input
                type="text"
                class="uk-input"
                placeholder="Tìm plugin..."
                data-plugin-search>
        </div>
        <div class="uk-flex-1 uk-margin-small-right">
            <select class="uk-select" data-plugin-select <?= $this->previewMode ? 'disabled' : '' ?>>
                <?php foreach ($pluginOptions as $code => $label): ?>
                    <option value="<?= e($code) ?>" <?= $selectedPlugin === $code ? 'selected' : '' ?>>
                        <?= e($label) ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
    </div>

    <div id="<?= $this->getId('permissionsContainer') ?>" data-permission-container>
        <?= $this->makePartial('permissioneditor_table'); ?>
    </div>
    <div class="permissions-overlay"></div>
</div>
<script>
    document.addEventListener("DOMContentLoaded", () => {
        const editor = document.querySelector(".permissioneditor");
        const container = editor?.querySelector("[data-permission-container]");
        const pluginSelect = editor?.querySelector("[data-plugin-select]");
        const pluginSearch = editor?.querySelector("[data-plugin-search]");
        const handler = "<?= $this->getEventHandler('onLoadPermissions') ?>";

        if (!editor || !container || !pluginSelect) {
            return;
        }

        let dirty = false;
        let currentPlugin = pluginSelect.value;
        const markDirty = () => {
            dirty = true;
            editor.classList.add("is-dirty");
        };

        const resetDirty = () => {
            dirty = false;
            editor.classList.remove("is-dirty");
        };

        const applySearchFilter = (input) => {
            const filter = input.value.toLowerCase();
            const tab = input.closest(".uk-accordion-content");

            tab?.querySelectorAll("tr[data-perm-item]").forEach((row) => {
                const text = row.innerText.toLowerCase();
                row.style.display = text.includes(filter) ? "" : "none";
            });
        };

        const toggleRows = (rows, mode, turnOn) => {
            if (mode === "radio") {
                rows.forEach((r) => {
                    const allow = r.querySelector('input[value="1"]');
                    const inherit = r.querySelector('input[value="0"]');
                    const deny = r.querySelector('input[value="-1"]');
                    if (!allow || !inherit || !deny) return;

                    if (allow.checked) inherit.checked = true;
                    else if (inherit.checked) deny.checked = true;
                    else if (deny.checked) allow.checked = true;
                    else inherit.checked = true;
                });
                return;
            }

            const checkboxes = [...rows].flatMap((r) => [...r.querySelectorAll('input[type="checkbox"]')]);
            const shouldTurnOn = typeof turnOn === "boolean"
                ? turnOn
                : checkboxes.filter((c) => c.checked).length <= checkboxes.length / 2;

            checkboxes.forEach((c) => { c.checked = shouldTurnOn; });
        };

        const bindTableEvents = () => {
            const tableWrap = container.querySelector("[data-permission-table]");
            if (!tableWrap) {
                return;
            }
            const mode = tableWrap.dataset.permissionMode;

            tableWrap.querySelectorAll('input[type="checkbox"], input[type="radio"]').forEach((input) => {
                input.addEventListener("change", markDirty, { once: false });
            });

            tableWrap.querySelectorAll("[data-permission-search]").forEach((searchBox) => {
                searchBox.addEventListener("keyup", (e) => applySearchFilter(e.target), { once: false });
            });

            tableWrap.addEventListener("click", (e) => {
                const groupBtn = e.target.closest("[data-group-toggle]");
                if (groupBtn) {
                    const group = groupBtn.dataset.group;
                    const rows = tableWrap.querySelectorAll(`tr[data-perm-group="${group}"]`);
                    toggleRows(rows, mode);
                    markDirty();
                    return;
                }

                const actionToggle = e.target.closest("[data-action-toggle]");
                if (actionToggle) {
                    e.preventDefault();
                    const action = actionToggle.dataset.action;
                    const rows = tableWrap.querySelectorAll(`tr[data-perm-action="${action}"]`);
                    toggleRows(rows, mode);
                    markDirty();
                }
            });

            const searchInput = tableWrap.querySelector("[data-permission-search]");
            if (searchInput) {
                applySearchFilter(searchInput);
            }
        };

        const handleGlobalToggle = () => {
            const tableWrap = container.querySelector("[data-permission-table]");
            if (!tableWrap) return;
            const mode = tableWrap.dataset.permissionMode;
            const rows = tableWrap.querySelectorAll("tr[data-perm-item]");
            const checkboxes = tableWrap.querySelectorAll('input[type="checkbox"]');

            let turnOn = true;
            if (mode !== "radio" && checkboxes.length) {
                const checkedCount = [...checkboxes].filter((c) => c.checked).length;
                turnOn = checkedCount <= checkboxes.length / 2;
            }

            toggleRows(rows, mode, turnOn);
            markDirty();
        };

        const loadPlugin = (pluginCode) => {
            if (!window.jQuery || typeof $.request !== "function") {
                return;
            }
            container.classList.add("loading");
            $.request(handler, {
                data: { plugin: pluginCode },
                success: (data) => {
                    if (data && data.result) {
                        container.innerHTML = data.result;
                        currentPlugin = pluginCode;
                        resetDirty();
                        bindTableEvents();

                        const globalToggleBtn = editor.querySelector("[data-global-toggle]");
                        if (globalToggleBtn) {
                            globalToggleBtn.addEventListener("click", handleGlobalToggle);
                        }
                    }
                },
                complete: () => container.classList.remove("loading"),
            });
        };

        if (window.jQuery) {
            $(document).on("ajaxSuccess", (_evt, context) => {
                if (context && context.handler && /onSave/i.test(context.handler)) {
                    resetDirty();
                }
            });
        }

        if (pluginSelect) {
            pluginSelect.addEventListener("change", () => {
                const nextPlugin = pluginSelect.value;
                if (dirty && !confirm("Bạn có thay đổi chưa lưu. Chuyển plugin sẽ bỏ qua thay đổi hiện tại.")) {
                    pluginSelect.value = currentPlugin;
                    return;
                }
                loadPlugin(nextPlugin);
            });
        }

        if (pluginSearch) {
            pluginSearch.addEventListener("input", () => {
                const term = pluginSearch.value.toLowerCase();
                const options = [...pluginSelect.options];
                let hasMatch = false;

                options.forEach((opt) => {
                    const hay = `${opt.textContent} ${opt.value}`.toLowerCase();
                    const match = hay.includes(term);
                    opt.hidden = !match;
                    opt.disabled = !match;
                    opt.style.display = match ? "" : "none";
                    if (match) {
                        hasMatch = true;
                    }
                });

                if (!hasMatch) {
                    options.forEach((opt) => {
                        opt.hidden = false;
                        opt.disabled = false;
                        opt.style.display = "";
                    });
                }
            });
        }

        const initialToggleBtn = editor.querySelector("[data-global-toggle]");
        if (initialToggleBtn) {
            initialToggleBtn.addEventListener("click", handleGlobalToggle);
        }

        bindTableEvents();
    });
</script>
