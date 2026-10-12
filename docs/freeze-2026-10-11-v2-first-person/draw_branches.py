import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

out = sys.argv[1]

BG = "#ffffff"
INK = "#1f2933"
MUTED = "#52606d"
ROOT = ("#eef1f4", "#52606d")
B550 = ("#fdf1dc", "#b7791f")
X99 = ("#e3f0fb", "#1f6fb2")
AC = ("#e4f5e8", "#2a7f3f")

fig = plt.figure(figsize=(18, 15.0), dpi=110)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, 180)
ax.set_ylim(-38, 112)
ax.axis("off")
fig.patch.set_facecolor(BG)


def box(x, y, w, h, colors, lw=2.0):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=1.6",
                                facecolor=colors[0], edgecolor=colors[1], linewidth=lw))


def arrow(x0, y0, x1, y1, color, lw=2.4, head=True):
    ax.add_patch(FancyArrowPatch((x0, y0), (x1, y1), arrowstyle="-|>" if head else "-", mutation_scale=18,
                                 color=color, linewidth=lw, shrinkA=0, shrinkB=0))


def label(x, y, text, color, size=10.0, ha="center", va="center"):
    ax.text(x, y, text, fontsize=size, fontweight="bold", color=color, ha=ha, va=va, zorder=6,
            bbox=dict(boxstyle="round,pad=0.2", facecolor="white", edgecolor=color, linewidth=0.9))


def card(x, y, w, h, colors, title, price, spec, fit, tsize=14.5, two_line=False):
    box(x, y, w, h, colors)
    if two_line:
        ax.text(x + 1.4, y + h - 2.2, title, fontsize=12.2, fontweight="bold", color=colors[1], va="top")
        ax.text(x + 1.4, y + h - 6.4, price, fontsize=12.2, fontweight="bold", color=colors[1], va="top")
        off = 11.8
    else:
        ax.text(x + 1.6, y + h - 2.4, f"{title} · {price}", fontsize=tsize, fontweight="bold", color=colors[1], va="top")
        off = 7.6
    ns = spec.count("\n") + 1
    ax.text(x + 1.5, y + h - off, spec, fontsize=10.2, color=INK, va="top", linespacing=1.36)
    y_fit_title = off + ns * 3.75 + 2.6
    ax.text(x + 1.5, y + h - y_fit_title, "Помещается:", fontsize=9.8, color=MUTED, va="top", fontweight="bold")
    ax.text(x + 1.5, y + h - y_fit_title - 3.5, fit, fontsize=10.0, color=INK, va="top", linespacing=1.38)


# заголовок
ax.text(90, 111.4, "Куда двигаться дальше: две ветки апгрейда", fontsize=22, fontweight="bold",
        color=INK, ha="center", va="top")
ax.text(90, 106.0, "цены в тр (тыс. руб., мои, б/у); «ОЗУ + VRAM» это общий объём, в который должны уместиться веса модели и кэш контекста",
        fontsize=11, color=MUTED, ha="center", va="top")

# --- левый столбец: b550 (сверху) и b550 - 1 (снизу)
LX, LW = 2, 30
top_y, top_h = 62, 34          # ряд X99
bot_y, bot_h = 10, 42          # ряд AC922

box(LX, top_y, LW, top_h, ROOT, lw=2.4)
ax.text(LX + 1.6, top_y + top_h - 2.4, "Сейчас b550 · 80 тр", fontsize=14, fontweight="bold", color=ROOT[1], va="top")
ax.text(LX + 1.6, top_y + top_h - 8.0,
        "домашний ПК (уже был)\n+ V100 32 ГБ: 50 тр\n+ 96 ГБ ОЗУ (AM4): 30 тр\n\nStrata, Qwen3.8-\nFlash-Next: 55–61 ток/с",
        fontsize=10.2, color=INK, va="top", linespacing=1.38)

card(LX, bot_y, LW, bot_h, B550, "b550 - 1", "95 тр",
     "b550 + переходник\n2×SXM2 NVLink\n2×V100 32 ГБ\n96 ГБ ОЗУ · всего 160 ГБ",
     "DeepSeek V4.1 Flash\nIQ4_XS 137 ⚠ (IQ3_S 116),\nGLM-5.3 Flash IQ3_XXS 120,\nMiniMax M3 1 бит ⚠", tsize=14)

# стрелка b550 -> b550 - 1 (вниз)
cx = LX + LW / 2
arrow(cx, top_y, cx, bot_y + bot_h, B550[1])
label(cx + 1.5, (top_y + bot_y + bot_h) / 2, "+95 тр", B550[1], size=9.5, ha="left")

# --- точка разветвления
JX = 40.0
mid_ac = bot_y + bot_h / 2
AC_X0 = 46.0
arrow(LX + LW, mid_ac, AC_X0, mid_ac, AC[1], lw=2.6)
label(38.5, mid_ac - 3.6, "+365 тр", AC[1], size=9.5)

# вверх к X99
x_mid = top_y + top_h / 2
arrow(JX, mid_ac, JX, x_mid, X99[1], lw=2.6, head=False)
arrow(JX, x_mid, 46, x_mid, X99[1], lw=2.6)
label(36.2, 57.0, "+155 тр", X99[1], size=9.5)

# --- ветка X99 (верхний ряд)
ax.text(46, 100.4, "Ветка X99: самосборная, DDR4 (память медленнее, около 120–150 ГБ/с суммарно)",
        fontsize=13, fontweight="bold", color=X99[1], va="top")
xw = 56
card(46, top_y, xw, top_h, X99, "x99 - 0", "250 тр",
     "X99 2P + 256 ГБ ОЗУ\nпереходник 2×SXM2 переношу с b550 - 1\n2×V100 32 ГБ · всего 320 ГБ",
     "GLM-5.x 2 бита, MiniMax M3 4 бита,\nGLM-5.3 Flash 5 бит, DeepSeek V4.1 Flash Q8")
card(120, top_y, xw, top_h, X99, "x99 - 1", "450 тр",
     "плата 4×SXM2 NVLink, 4×V100 32 ГБ\n(докупаю 2 карты до комплекта)\n256 ГБ ОЗУ · всего 384 ГБ",
     "GLM-5.x 3 бита, MiniMax M3 5 бит,\nKimi K2.7 Code 1–2 бита, GLM-5.3 Flash Q8")
arrow(46 + xw, x_mid, 120, x_mid, X99[1])
label(46 + xw + (120 - 46 - xw) / 2, x_mid + 3.2, "+200 тр", X99[1], size=10)

# --- ветка IBM AC922 (нижний ряд)
ax.text(46, 57.0, "Ветка IBM AC922: готовый сервер на Power9 (память до ~340 ГБ/с)",
        fontsize=13, fontweight="bold", color=AC[1], va="top")
ac_w, gap = 22.0, 5.5
nodes = [
    ("IBM AC922 - 0", "365 тр", "6×V100 16 ГБ\n256 ГБ ОЗУ\nвсего 352 ГБ",
     "GLM-5.x 2 бита,\nMiniMax M3 4 бита,\nKimi K2.7 1 бит ⚠"),
    ("IBM AC922 - 1", "465 тр", "6×V100 16 ГБ\n512 ГБ ОЗУ\nвсего 608 ГБ",
     "Qwen3.8-Max 1 бит,\nV4 Pro 1–2 бита,\nMiMo 3 бита,\nGLM-5.x 4 бита"),
    ("IBM AC922 - 2", "573 тр", "4×16 + 2×32 ГБ\n512 ГБ ОЗУ\nвсего 640 ГБ",
     "как в AC922 - 1,\n+ Kimi K3 1 бит ⚠\n(лишь +32 ГБ\nза 108 тр)"),
    ("IBM AC922 - 3", "933 тр", "6×V100 32 ГБ\n1 ТБ ОЗУ\nвсего 1,2 ТБ",
     "Qwen3.8-Max 3 бита,\nKimi K3 2 бита,\nV4 Pro Q8,\nGLM-5.x 8 бит"),
    ("IBM AC922 - 4", "1 589 тр", "6×V100 32 ГБ\n2 ТБ ОЗУ\nвсего 2,2 ТБ",
     "Kimi K3 4–8 бит,\nQwen3.8-Max 4 бита,\nGLM-5.x BF16"),
]
deltas = ["+100 тр", "+108 тр", "+360 тр", "+656 тр"]
x = AC_X0
for i, (t, p, s, f) in enumerate(nodes):
    card(x, bot_y, ac_w, bot_h, AC, t, p, s, f, two_line=True)
    if i < len(nodes) - 1:
        arrow(x + ac_w, mid_ac, x + ac_w + gap, mid_ac, AC[1], lw=2.0)
        label(x + ac_w + gap / 2, mid_ac + 3.0, deltas[i], AC[1], size=8.2)
    x += ac_w + gap

# --- для сравнения: NVIDIA DGX Spark (не ветка апгрейда)
GRAY = ("#f4f4f5", "#71717a")
ax.text(2, 5.6, "Для сравнения (не ветка апгрейда): готовая компактная станция NVIDIA DGX Spark",
        fontsize=13, fontweight="bold", color=GRAY[1], va="top")
dx, dy, dw, dh = 2, -26, 176, 28
ax.add_patch(FancyBboxPatch((dx, dy), dw, dh, boxstyle="round,pad=0.0,rounding_size=1.6",
                            facecolor=GRAY[0], edgecolor=GRAY[1], linewidth=2.0, linestyle=(0, (6, 4))))
ax.text(dx + 1.6, dy + dh - 2.4, "NVIDIA DGX Spark · 520 тр", fontsize=14.5, fontweight="bold", color=GRAY[1], va="top")
ax.text(dx + 1.6, dy + dh - 8.0,
        "GB10 (Blackwell + 20 ядер Arm) · 128 ГБ единой памяти LPDDR5x, 273 ГБ/с · NVMe 4 ТБ\n"
        "ОЗУ + VRAM 128 ГБ (как у «Сейчас b550», чуть меньше b550 - 1), весов до ~115 ГБ",
        fontsize=10.4, color=INK, va="top", linespacing=1.4)
ax.text(dx + 1.6, dy + dh - 15.6, "Помещается:", fontsize=9.8, color=MUTED, va="top", fontweight="bold")
ax.text(dx + 1.6, dy + dh - 18.8,
        "DeepSeek V4.1 Flash IQ3_XXS 104, GLM-5.3 Flash IQ2_XXS 102 (IQ3_XXS 120 ⚠); MiniMax M3 и все крупные модели не помещаются.",
        fontsize=10.0, color=INK, va="top")
ax.text(dx + 1.6, dy + dh - 22.2,
        "Скорость по обзорам: gpt-oss-120b 38–60 ток/с (llama.cpp), Qwen3 30B-A3B ~89, плотная 70B ~3; мой стенд b550 на Qwen3.8-Flash-Next 55–61 ток/с.",
        fontsize=10.0, color=INK, va="top")

# сноска
ax.text(2, -32.5,
        "Числа на стрелках: доплата за переход к следующей сборке. Цена в карточке: для b550 и X99 нарастающим итогом от «Сейчас b550», "
        "для IBM AC922 — сервер целиком\n(в ветке AC922 старая память продаётся по цене покупки; карты из b550 - 1 в цену сервера не входят). "
        "Размеры квантов: Unsloth и Hugging Face, для DeepSeek V4 Pro и MiMo оценочные; 1–2-битные кванты заметно\nтеряют в качестве. "
        "Скорость на этих сборках я не измерял. Цены X99 без охлаждения. Стенд b550: 80 тр (V100 50 + память 30) сверх домашнего ПК, который уже был;\n"
        "к ценам b550 - 1 и X99 их можно прибавить (всего вложено: 175, 330 и 530 тр).",
        fontsize=9, color=MUTED, va="center", linespacing=1.45)

fig.savefig(out, dpi=110, facecolor=BG)
print("saved", out)
