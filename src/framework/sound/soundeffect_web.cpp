#include "soundeffect.h"

// Emscripten provides basic OpenAL audio, but not the EFX reverb extension.
SoundEffect::SoundEffect(ALCdevice* device) : m_device(device) {}
SoundEffect::~SoundEffect() = default;

void SoundEffect::init(ALCdevice* device) { m_device = device; }
void SoundEffect::setPreset(const std::string&) {}
void SoundEffect::setReverbDensity(float) const {}
void SoundEffect::setReverbDiffusion(float) const {}
void SoundEffect::setReverbGain(float) const {}
void SoundEffect::setReverbGainHF(float) const {}
void SoundEffect::setReverbGainLF(float) const {}
void SoundEffect::setReverbDecayTime(float) const {}
void SoundEffect::setReverbDecayHfRatio(float) const {}
void SoundEffect::setReverbDecayLfRatio(float) const {}
void SoundEffect::setReverbReflectionsGain(float) const {}
void SoundEffect::setReverbReflectionsDelay(float) const {}
