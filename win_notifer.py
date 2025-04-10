import time
import datetime
import sys
import platform

# Check if running on Windows
if platform.system() != "Windows":
    print("Error: This script uses 'winsound' and is designed for Windows only.")
    sys.exit(1)

# Import winsound only if on Windows
import winsound

# --- Configuration ---
INTERVAL_SECONDS = 300 # 60 seconds = 1 minute

# Option A: Play a standard system sound alias
# Common aliases: 'SystemAsterisk', 'SystemExclamation', 'SystemHand', 'SystemQuestion', 'SystemExit'
SOUND_ALIAS = 'SystemAsterisk' # Change this alias if desired
USE_ALIAS = True # Set to False to use Beep or a WAV file instead

# Option B: Generate a simple beep (if USE_ALIAS = False and USE_WAV = False)
BEEP_FREQUENCY = 1000 # Hz (between 37 and 32767)
BEEP_DURATION = 300   # Milliseconds

# Option C: Play a specific WAV file (if USE_ALIAS = False)
WAV_FILE = "C:\\Windows\\Media\\notify.wav" # Example path, change if needed
USE_WAV = True # Set to True to use a WAV file, False to use Beep (if USE_ALIAS is False)
# --- End Configuration ---

# --- Input Validation ---
if not isinstance(INTERVAL_SECONDS, (int, float)) or INTERVAL_SECONDS <= 0:
    print(f"Error: INTERVAL_SECONDS must be a positive number. Found: {INTERVAL_SECONDS}")
    sys.exit(1)
# --- End Input Validation ---


def play_windows_notification():
    """Plays the notification sound using winsound."""
    try:
        print(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} - Playing notification...")
        if USE_ALIAS:
            print(f"(Using alias: {SOUND_ALIAS})")
            winsound.PlaySound(SOUND_ALIAS, winsound.SND_ALIAS)
        elif USE_WAV:
            print(f"(Using WAV file: {WAV_FILE})")
            # SND_FILENAME: Play specified file. SND_ASYNC: Play asynchronously (doesn't block script)
            winsound.PlaySound(WAV_FILE, winsound.SND_FILENAME | winsound.SND_ASYNC)
        else:
            print(f"(Using Beep: {BEEP_FREQUENCY} Hz, {BEEP_DURATION} ms)")
            winsound.Beep(BEEP_FREQUENCY, BEEP_DURATION)
    except RuntimeError as e:
        print(f"\nError playing sound with winsound: {e}")
        print("Check if the sound alias/file exists or if another sound is playing.")
    except Exception as e:
        print(f"\nAn unexpected error occurred during sound playback: {e}")


if __name__ == "__main__":
    print(f"--- Windows Notification Script Started (using winsound) ---")
    print(f"Triggering sound every {INTERVAL_SECONDS} seconds.")
    print("Press Ctrl+C to stop.")
    print("-" * 55)

    try:
        while True:
            play_windows_notification()
            # If playing WAV asynchronously, the main script continues immediately.
            # If using PlaySound synchronously or Beep, it waits for the sound to finish.
            # The sleep below ensures the interval *between starts* of sounds.
            print(f"Waiting for {INTERVAL_SECONDS} seconds...")
            time.sleep(INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\n--- Notification Script Stopped by User ---")
    except Exception as e:
        print(f"\n--- An Unexpected Error Occurred ---")
        print(f"Error details: {e}")
    finally:
        print("Exiting.")