#!/usr/bin/env python3
"""
Lightning Whisper MLX Transcription Script

This script provides a command-line interface for transcribing audio files
using lightning-whisper-mlx on Apple Silicon Macs.

Usage:
    python lightning_whisper_transcribe.py --audio <path> --model <model_name> --output <output_path> [--language <lang>]

Models available:
    tiny, small, distil-small.en, base, medium, distil-medium.en,
    large, large-v2, distil-large-v2, large-v3, distil-large-v3
"""

import argparse
import sys
import os
import json

def main():
    parser = argparse.ArgumentParser(description='Transcribe audio using Lightning Whisper MLX')
    parser.add_argument('--audio', '-a', required=True, help='Path to audio file')
    parser.add_argument('--model', '-m', default='distil-small.en', help='Model to use for transcription')
    parser.add_argument('--output', '-o', required=True, help='Output file path (without extension)')
    parser.add_argument('--language', '-l', default=None, help='Language code (e.g., en, es, fr). None for auto-detect')
    parser.add_argument('--json', action='store_true', help='Output as JSON with timestamps')

    args = parser.parse_args()

    # Verify audio file exists
    if not os.path.exists(args.audio):
        print(f"Error: Audio file not found: {args.audio}", file=sys.stderr)
        sys.exit(1)

    try:
        from lightning_whisper_mlx import LightningWhisperMLX
    except ImportError:
        print("Error: lightning-whisper-mlx is not installed.", file=sys.stderr)
        print("Install it with: pip install lightning-whisper-mlx", file=sys.stderr)
        sys.exit(1)

    try:
        # Initialize the model
        whisper = LightningWhisperMLX(model=args.model, batch_size=12, quant=None)

        # Transcribe the audio
        result = whisper.transcribe(audio_path=args.audio, language=args.language)

        # Extract transcription text
        if isinstance(result, dict):
            text = result.get('text', '')
        else:
            text = str(result)

        # Clean up the transcription
        text = text.strip()

        # Write output
        output_txt = args.output + '.txt'
        with open(output_txt, 'w', encoding='utf-8') as f:
            f.write(text)

        # Optionally write JSON with more details
        if args.json and isinstance(result, dict):
            output_json = args.output + '.json'
            with open(output_json, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)

        print(f"Transcription saved to: {output_txt}")
        sys.exit(0)

    except Exception as e:
        print(f"Error during transcription: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
