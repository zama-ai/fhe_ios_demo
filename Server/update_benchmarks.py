import pandas as pd
import matplotlib.pyplot as plt

README_PATH = "README.md"
BENCHMARK_PATH = "benchmark.csv"


pd.set_option("display.max_columns", None)
pd.set_option("display.width", 0)

# Load data
# Columns are: date;env;machine;task_name;server_execution_time(s);end_to_end_execution_time(s);device
df = pd.read_csv(BENCHMARK_PATH, sep=";")

df["env"] = df["env"].str.lower()
df["machine"] = df["machine"].str.lower()
df["device"] = df["device"].str.lower()
df["task_name"] = df["task_name"].str.lower()

print(f"{df.shape=}")
print(f"DF:\n{df.head(-3)}\n")

# Grouped stats
agg_cols = ["server_execution_time(s)", "end_to_end_execution_time(s)"]
grp_cols = [ "task_name", "machine", "device", "env"]
grouped = df.groupby(grp_cols)[agg_cols].agg(["mean", "std", "min", "max"]).reset_index().round(2)
grouped.columns = ['_'.join(col) if len(col[1]) else col[0] for col in grouped.columns]
print(f"Grouped DF:\n{grouped}\n")

# Split and align data by task and device
cpu_data = grouped[grouped["device"] == "cpu"].set_index("task_name").sort_index()
cuda_data = grouped[grouped["device"] == "cuda"].set_index("task_name").sort_index()
tasks = cpu_data.index.tolist()
x = range(len(tasks))
width = 0.2

# Plot
plt.figure(figsize=(12, 7))

# CPU Bars (upper)
plt.bar([p - 1.5*width for p in x],
        cpu_data["end_to_end_execution_time(s)_mean"],
        width,
        yerr=cpu_data["end_to_end_execution_time(s)_std"],
        capsize=5,
        label="E2E Time (CPU)",
        color="steelblue")

plt.bar([p - 0.5*width for p in x],
        cpu_data["server_execution_time(s)_mean"],
        width,
        yerr=cpu_data["server_execution_time(s)_std"],
        capsize=5,
        label="Server Time (CPU)",
        color="skyblue")

# CUDA Bars (lower, negative direction)
plt.bar([p + 0.5*width for p in x],
        -cuda_data["end_to_end_execution_time(s)_mean"],
        width,
        yerr=cuda_data["end_to_end_execution_time(s)_std"],
        capsize=5,
        label="E2E Time (CUDA)",
        color="darkorange")

plt.bar([p + 1.5*width for p in x],
        -cuda_data["server_execution_time(s)_mean"],
        width,
        yerr=cuda_data["server_execution_time(s)_std"],
        capsize=5,
        label="Server Time (CUDA)",
        color="lightsalmon")

plt.axhline(0, color='black', linewidth=0.8)
plt.xticks(x, tasks, rotation=15)
plt.ylabel("Execution Time (s)\n(negative = CUDA)")
plt.title("Execution time per use case: CPU (↑) vs CUDA (↓)") 
plt.legend()
plt.grid(axis='y')
plt.tight_layout()
plt.savefig("images/fhe_cpu_performance.png", dpi=300)

# Markdown table
lines = [
    "Task | Device | Server time (avg ± std) | E2E time (avg ± std) | Server time range (s) | E2E time range (s)",
    "-----|--------|-------------------------|----------------------|-----------------------|----------------------"
]

for _, row in grouped.iterrows():
    line = (
        f"{row['task_name']} | "
        f"{row['device']} | "
        f"{row['server_execution_time(s)_mean']:.2f} ± {row['server_execution_time(s)_std']:.2f} s | "
        f"{row['end_to_end_execution_time(s)_mean']:.2f} ± {row['end_to_end_execution_time(s)_std']:.2f} s | "
        f"{row['server_execution_time(s)_min']:.2f} - {row['server_execution_time(s)_max']:.2f} | "
        f"{row['end_to_end_execution_time(s)_min']:.2f} - {row['end_to_end_execution_time(s)_max']:.2f}"
    )
    lines.append(line)

markdown = "\n".join(lines)

# Inject  the table into  the README
with open(README_PATH, "r") as f:
    content = f.read()

start, end = "<!-- BENCHMARK_TABLE_START -->", "<!-- BENCHMARK_TABLE_END -->"
text_before = content.split(start)[0]

text_after  = content.split(end)[1]
new_content = f"{text_before}{start}\n{markdown}\n{end}{text_after}"

with open(README_PATH, "w") as f:
    f.write(new_content)

print("Updated plot and benchmark table in README.md.")
