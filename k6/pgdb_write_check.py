import requests
import time

END_POINT = "http://localhost:8080/api/telemetry/count/e003031d-e441-4ece-ba5b-7d54d5b1da21"
API_Key = "device-001"
DURATION = 900


def write_count(url: str) -> None:

    headers = {
        'X-API-KEY': API_Key,
        'Accept': 'application/json'
    }

    for i in range(DURATION):
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            status = response.status_code
            total = data["total_events"]
            print(f"status:{status}; total: {total}")
        else:
            print(f"Error: Received status code {response.status_code}")

        time.sleep(1)


if __name__ == "__main__":
    write_count(url=END_POINT)
