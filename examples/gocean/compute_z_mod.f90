!> \brief Compute the potential vorticity, z
!! \detail Given the current pressure and velocity fields,
!! computes the potential voriticity.
module compute_z_mod
  use kind_params_mod
  use kernel_mod
  use argument_mod
  use grid_mod
  use field_mod
  implicit none

  private

  public invoke_compute_z
  public compute_z, compute_z_code

  type, extends(kernel_type) :: compute_z
     type(arg), dimension(6) :: meta_args =    &
          (/ arg(WRITE, CF, POINTWISE),        & ! z
             arg(READ,  CT, POINTWISE),        & ! p
             arg(READ,  CU, POINTWISE),        & ! u
             arg(READ,  CV, POINTWISE),        & ! v
             arg(READ,  GRID_DX_CONST),        & ! dx
             arg(READ,  GRID_DY_CONST)         & ! dy
           /)
     !> This kernel operates on fields that live on an
     !! orthogonal, regular grid.
     integer :: GRID_TYPE = ORTHOGONAL_REGULAR

     !> This kernel writes only to internal points of the
     !! simulation domain.
     integer :: ITERATES_OVER = INTERNAL_PTS
  
     !> Although the staggering of variables used in an Arakawa
     !! C grid is well defined, the way in which they are indexed is
     !! an implementation choice. This can be thought of as choosing
     !! which grid-point types have the same (i,j) index as a T
     !! point. This kernel assumes that the U,V and F points that
     !! share the same index as a given T point are those immediately
     !! to the South and West of it.
     integer :: index_offset = OFFSET_SW

   contains
     procedure, nopass :: code => compute_z_code
  end type compute_z

contains

  !===================================================

  !> Manual implementation of the code needed to invoke
  !! compute_z_code().
  subroutine invoke_compute_z(zfld, pfld, ufld, vfld)
    implicit none
    type(r2d_field), intent(inout) :: zfld
    type(r2d_field), intent(in)    :: pfld, ufld, vfld
    ! Locals
    integer :: I, J
    real(wp) :: dx, dy

    dx = zfld%grid%dx
    dy = zfld%grid%dy

    do J=zfld%internal%ystart, zfld%internal%ystop, 1
       do I=zfld%internal%xstart, zfld%internal%xstop, 1

          call compute_z_code(i, j,      &
                              zfld%data, &
                              pfld%data, &
                              ufld%data, &
                              vfld%data, &
                              dx, dy)

       end do
    end do

  end subroutine invoke_compute_z

  !===================================================

  !> Compute the potential vorticity on the grid point (i,j)
  subroutine compute_z_code(i, j, z, p, u, v, dx, dy)
    implicit none
    integer,  intent(in) :: I, J
    real(wp), intent(in) :: dx, dy
    real(wp), intent(inout), dimension(:,:) :: z
    real(wp), intent(in),  dimension(:,:) :: p, u, v

    ! Original code looked like:
    ! DO J=1,N
    !    DO I=1,M
    !       Z(I+1,J+1) =(FSDX*(V(I+1,J+1)-V(I,J+1))-FSDY*(U(I+1,J+1) & 
    !                    -U(I+1,J)))/(P(I,J)+P(I+1,J)+P(I+1,J+1)+P(I,J+1))

    Z(I,J) =( (4.0d0/dx)*( V(I,J)-V(I-1,J))-    &
              (4.0d0/dy)*( U(I,J)-U(I,J-1)) ) / &
            (P(I-1,J-1)+P(I,J-1)+ P(I,J)+P(I-1,J))

  end subroutine compute_z_code

end module compute_z_mod
