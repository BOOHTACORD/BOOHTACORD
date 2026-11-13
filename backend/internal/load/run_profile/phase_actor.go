package run_profile

import "context"

func (r *Runner) exercise(ctx, workCtx context.Context, name string, iteration, index int) error {
	a := r.actors[index]
	if err := recoverFaultSocket(ctx, r.Profile, a); err != nil {
		return err
	}
	var err error
	if r.Profile == "reconnect" && name == "spike" {
		err = a.Reconnect(workCtx)
	} else {
		err = a.Read(workCtx)
		if err == nil {
			err = a.Message(workCtx, r.actors, nil)
		}
	}
	if err == nil && iteration == 0 {
		err = a.ACL(workCtx)
	}
	if err == nil && r.Profile == "uploads" && (name == "steady" || name == "spike") && index < 4 && iteration == 0 {
		err = a.Upload(workCtx, r.actors)
		if err == nil && index == 0 {
			err = a.UploadLimit(workCtx)
		}
	}
	return err
}
